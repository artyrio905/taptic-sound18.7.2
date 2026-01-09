import Foundation
import AVFoundation
import CoreHaptics

final class AudioHapticEngine {
    private let audioEngine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    private var hapticEngine: CHHapticEngine?
    private var hapticPlayer: CHHapticAdvancedPatternPlayer?

    private var onIntensity: ((Double) -> Void)?

    // haptics-only mode
    private var hapticsTimer: DispatchSourceTimer?
    private var fileReader: AVAudioFile?
    private var readFramePos: AVAudioFramePosition = 0
    private var framesPerTick: AVAudioFrameCount = 1024

    func start(
        url: URL,
        gain: Double,
        hapticsOnly: Bool,
        onIntensity: @escaping (Double) -> Void
    ) throws {
        self.onIntensity = onIntensity

        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)

        try startHapticsIfPossible()
        try startContinuousHaptic()

        if hapticsOnly {
            try startHapticsOnlyMode(url: url, gain: gain)
        } else {
            try startAudioAndTapMode(url: url, gain: gain)
        }
    }

    func stop() {
        // stop timer mode
        hapticsTimer?.cancel()
        hapticsTimer = nil
        fileReader = nil
        readFramePos = 0

        // stop audio engine mode
        audioEngine.mainMixerNode.removeTap(onBus: 0)
        player.stop()
        audioEngine.stop()

        try? hapticPlayer?.stop(atTime: 0)
        hapticPlayer = nil

        hapticEngine?.stop(completionHandler: nil)
        hapticEngine = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        onIntensity?(0.0)
    }

    // MARK: - Mode A: audio plays, analyze via tap
    private func startAudioAndTapMode(url: URL, gain: Double) throws {
        let file = try AVAudioFile(forReading: url)

        audioEngine.stop()
        audioEngine.reset()

        audioEngine.attach(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: file.processingFormat)

        let bus = 0
        let format = audioEngine.mainMixerNode.outputFormat(forBus: bus)

        audioEngine.mainMixerNode.removeTap(onBus: bus)
        audioEngine.mainMixerNode.installTap(onBus: bus, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let (amp, brightness) = self.features(buffer: buffer)
            self.pushHaptics(amp: amp, brightness: brightness, gain: gain)
        }

        try audioEngine.start()
        player.scheduleFile(file, at: nil, completionHandler: nil)
        player.play()
    }

    // MARK: - Mode B: haptics only (speaker muted)
    private func startHapticsOnlyMode(url: URL, gain: Double) throws {
        let file = try AVAudioFile(forReading: url)
        fileReader = file
        readFramePos = 0

        let sr = file.processingFormat.sampleRate
        let tickHz: Double = 120 // 60..180 можно тюнить
        framesPerTick = AVAudioFrameCount(max(256, Int(sr / tickHz)))

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        timer.schedule(deadline: .now(), repeating: 1.0 / tickHz)

        timer.setEventHandler { [weak self] in
            guard let self else { return }
            guard let file = self.fileReader else { return }

            let format = file.processingFormat
            let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: self.framesPerTick)!

            do {
                file.framePosition = self.readFramePos
                try file.read(into: buf, frameCount: self.framesPerTick)
                self.readFramePos += AVAudioFramePosition(buf.frameLength)

                if buf.frameLength == 0 {
                    self.stop()
                    return
                }

                let (amp, brightness) = self.features(buffer: buf)
                self.pushHaptics(amp: amp, brightness: brightness, gain: gain)
            } catch {
                self.stop()
            }
        }

        hapticsTimer = timer
        timer.resume()
    }

    // MARK: - Audio features
    private func features(buffer: AVAudioPCMBuffer) -> (amp: Double, brightness: Double) {
        guard let channel = buffer.floatChannelData?[0] else { return (0, 0) }
        let n = Int(buffer.frameLength)
        if n == 0 { return (0, 0) }

        var sumSq: Double = 0
        var diffSum: Double = 0

        var prev = Double(channel[0])
        for i in 0..<n {
            let x = Double(channel[i])
            sumSq += x * x
            diffSum += abs(x - prev)
            prev = x
        }

        let rms = sqrt(sumSq / Double(n))
        let brightness = min(1.0, (diffSum / Double(n)) * 30.0)
        return (rms, brightness)
    }

    private func pushHaptics(amp: Double, brightness: Double, gain: Double) {
        let intensity = min(1.0, max(0.0, (amp * 18.0) * gain))
        let sharp = min(1.0, max(0.0, 0.10 + brightness * 0.90))

        onIntensity?(intensity)
        updateHaptics(intensity: intensity, sharpness: sharp)
    }

    // MARK: - Haptics
    private func startHapticsIfPossible() throws {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try CHHapticEngine()
        try hapticEngine?.start()
    }

    private func startContinuousHaptic() throws {
        guard let hapticEngine else { return }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensity, sharpness],
            relativeTime: 0,
            duration: 120
        )

        let pattern = try CHHapticPattern(events: [event], parameters: [])
        hapticPlayer = try hapticEngine.makeAdvancedPlayer(with: pattern)
        try hapticPlayer?.start(atTime: 0)
    }

    private func updateHaptics(intensity: Double, sharpness: Double) {
        guard let hapticPlayer else { return }

        let params = [
            CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: Float(intensity), relativeTime: 0),
            CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: Float(sharpness), relativeTime: 0)
        ]
        try? hapticPlayer.sendParameters(params, atTime: 0)
    }
}
