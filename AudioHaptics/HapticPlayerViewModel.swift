import Foundation
import SwiftUI

@MainActor
final class HapticPlayerViewModel: ObservableObject {
    @Published var intensity: Double = 0
    @Published var isRunning: Bool = false
    @Published var hapticsOnly: Bool = false
    @Published var gain: Double = 1.0
    @Published var pickedURL: URL? = nil

    private let engine = AudioHapticEngine()

    func start() {
        guard let url = pickedURL else {
            print("No MP3 selected")
            return
        }

        do {
            try engine.start(url: url, gain: gain, hapticsOnly: hapticsOnly) { [weak self] v in
                Task { @MainActor in self?.intensity = v }
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
