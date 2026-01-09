import Foundation
import AVFoundation
import CoreHaptics

final class AudioHapticEngine {
    private let audioEngine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    private var hapticEngine: CHHapticEngine?
    private var hapticPlayer: CHHapticAdvancedPatternPlayer?

    private var onIntensity: ((Double) -> Void)?

    func start(url: URL, gain: Double, onIntensity: @escaping (Double) -> Void) throws {
        self.onIntensity = onIntensity

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
            let amp = self.rmsAmplitude(buffer: buffer)

            let normalized = min(1.0, max(0.0, (amp * 18.0) * gain))
            self.onIntensity?(normalized)
            self.updateHaptics(intensity: normalized)
        }

        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)

        try audioEngine.start()
        player.scheduleFile(file, at: nil, completionHandler: nil)
        player.play()

        try startHapticsIfPossible()
        try startContinuousHaptic()
    }

    func stop() {
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

    private func rmsAmplitude(buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }
        let frameLength = Int(buffer.frameLength)
        if frameLength == 0 { return 0.0 }

        var sum: Double = 0
        for i in 0..<frameLength {
            let x = Double(channelData[i])
            sum += x * x
        }
        return sqrt(sum / Double(frameLength))
    }

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
            duration: 60
        )

        let pattern = try CHHapticPattern(events: [event], parameters: [])
        hapticPlayer = try hapticEngine.makeAdvancedPlayer(with: pattern)
        try hapticPlayer?.start(atTime: 0)
    }

    private func updateHaptics(intensity: Double) {
        guard let hapticPlayer else { return }

        let i = Float(intensity)
        let s = Float(min(1.0, max(0.0, 0.15 + intensity * 0.85)))

        let params = [
            CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: i, relativeTime: 0),
            CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: s, relativeTime: 0)
        ]

        do {
            try hapticPlayer.sendParameters(params, atTime: 0)
        } catch {
            // ignore hiccups
        }
    }
}
