import Foundation
import SwiftUI

@MainActor
final class HapticPlayerViewModel: ObservableObject {
    @Published var intensity: Double = 0
    @Published var isRunning: Bool = false
    @Published var hapticsOnly: Bool = false
    @Published var gain: Double = 1.0

    private let engine = AudioHapticEngine()

    func startWithBundledFile() {
        guard let url = Bundle.main.url(forResource: "song", withExtension: "mp3") else {
            print("ERROR: song.mp3 not found in bundle")
            return
        }

        do {
            try engine.start(url: url, gain: gain, hapticsOnly: hapticsOnly) { [weak self] value in
                Task { @MainActor in
                    self?.intensity = value
                }
            }
            isRunning = true
        } catch {
            print("Start error:", error)
            isRunning = false
        }
    }

    func stop() {
        engine.stop()
        intensity = 0
        isRunning = false
    }

    func test() {
        engine.testHaptic()
    }
}
