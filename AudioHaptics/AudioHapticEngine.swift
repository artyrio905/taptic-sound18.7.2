import Foundation
import AVFoundation
import CoreHaptics
import UIKit

final class AudioHapticEngine {
    private let audioEngine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    private var hapticEngine: CHHapticEngine?
    private var hapticPlayer: CHHapticAdvancedPatternPlayer?

    private var onIntensity: ((Double) -> Void)?
    private var currentGain: Double = 1.0

    // MARK: - Public

    func start(
        url: URL,
        gain: Double,
        hapticsOnly: Bool,
        onIntensity: @escaping (Double) -> Void
    ) throws {
        self.onIntensity = onIntensity
        self.currentGain = gain

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)

        try startHapticsIfPossible()
        try startContinuousHaptic()

        try startAudioAndTap(url: url)

        // Haptics-only: звук не слышим, но playback идёт (и tap работает)
        if hapticsOnly {
            player.volume = 0.0
            audioEngine.mainMixerNode.outputVolume = 0.0
        } else {
            player.volume = 1.0
            audioEngine.mainMixerNode.outputVolume = 1.0
        }
    }

    func stop() {
        player.removeTap(onBus: 0)

        player.stop()
        audioEngine.stop()
        audioEngine.reset()

        try? hapticPlayer?.stop(atTime: 0)
        hapticPlayer = nil

        hapticEngine?.stop(completionHandler: nil)
        hapticEngine = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        onIntensity?(0.0)
    }

    func testHaptic() {
        DispatchQueue.main.async {
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(.success)
        }

        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            if hapticEngine == nil { try startHapticsIfPossible() }

            let e1 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [e1], parameters: [])
            let p = try hapticEngine?.makePlayer(with: pattern)
            try p?.start(atTime: 0)
        } catch {}
    }

    // MARK: - Audio + Tap (ВАЖНО: tap на player)

    private func startAudioAndTap(url: URL) throws {
        let file = try AVAudioFile(forReading: url)

        audioEngine.stop()
        audioEngine.reset()

        audioEngine.attach(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: file.processingFormat)

        // Tap именно на player — так гарантированно видим реальные сэмплы
        player.removeTap(onBus: 0)
        player.installTap(onBus: 0, bufferSize: 1024, format: file.processingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let (amp, brightness) = self.features(buffer: buffer)
            self.pushHaptics(amp: amp, brightness: brightness, gain: self.currentGain)
        }

        try audioEngine.start()
        player.scheduleFile(file, at: nil, completionHandler: nil)
        player.play()
    }

    // MARK: - Features

    private func features(buffer: AVAudioPCMBuffer) -> (amp: Double, brightness: Double) {
        guard let data = buffer.floatChannelData else { return (0, 0) }
        let channels = Int(buffer.format.channelCount)
        let n = Int(buffer.frameLength)
        if n == 0 { return (0, 0) }

        var sumSq: Double = 0
        var diffSum: Double = 0

        for ch in 0..<max(1, channels) {
            var prev = Double(data[ch][0])
            for i in 0..<n {
                let x = Double(data[ch][i])
                sumSq += x * x
                diffSum += abs(x - prev)
                prev = x
            }
        }

        let denom = Double(n * max(1, channels))
        let rms = sqrt(sumSq / denom)
        let brightness = min(1.0, (diffSum / denom) * 22.0)

        return (rms, brightness)
    }

    private func pushHaptics(amp: Double, brightness: Double, gain: Double) {
        // iPhone 12 Pro: делаем более “жирную” отдачу
        // amp часто очень маленький, поэтому нужен shaping + порог
        let scaled = amp * 85.0 * max(0.1, gain)
        let shaped = pow(max(0.0, scaled), 0.55)

        let intensity = min(1.0, max(0.18, shaped))
        let sharp = min(1.0, max(0.12, 0.18 + brightness * 0.82))

        onIntensity?(intensity)
        updateHaptics(intensity: intensity, sharpness: sharp)
    }

    // MARK: - Haptics

    private func startHapticsIfPossible() throws {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        let engine = try CHHapticEngine()
        engine.isAutoShutdownEnabled = false

        engine.resetHandler = { [weak self] in
            guard let self else { return }
            do {
                try self.hapticEngine?.start()
                try self.startContinuousHaptic()
            } catch {
                print("Haptics reset error:", error)
            }
        }

        hapticEngine = engine
        try hapticEngine?.start()
    }

    private func startContinuousHaptic() throws {
        guard let hapticEngine else { return }

        let i = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.0)
        let s = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [i, s],
            relativeTime: 0,
            duration: 3600
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
