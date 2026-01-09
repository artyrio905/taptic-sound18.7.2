import Foundation
import SwiftUI

@MainActor
final class HapticPlayerViewModel: ObservableObject {
    @Published var showImporter = false
    @Published var audioURL: URL?
    @Published var isPlaying = false
    @Published var intensity: Double = 0.0
    @Published var userGain: Double = 1.0
    @Published var hapticsOnly: Bool = false

    private let engine = AudioHapticEngine()

    func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importToSandbox(url)
        case .failure(let error):
            print("Import error:", error)
        }
    }

    func handleIncomingURL(_ url: URL) {
        importToSandbox(url)
    }

    private func importToSandbox(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        let allowed = ["mp3", "m4a", "wav", "aiff", "aac", "caf", "flac", "ogg"]
        guard allowed.contains(ext) else {
            print("Not supported extension:", ext)
            return
        }

        do {
            let dst = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)

            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(at: dst)
            }

            try FileManager.default.copyItem(at: url, to: dst)
            audioURL = dst
        } catch {
            print("Copy error:", error)
        }
    }

    func testHaptic() {
        engine.testHaptic()
    }

    func play() {
        guard let url = audioURL else { return }
        if isPlaying { return }

        do {
            try engine.start(
                url: url,
                gain: userGain,
                hapticsOnly: hapticsOnly
            ) { [weak self] currentIntensity in
                Task { @MainActor in
                    self?.intensity = currentIntensity
                }
            }
            isPlaying = true
        } catch {
            print("Play error:", error)
            isPlaying = false
        }
    }

    func stop() {
        engine.stop()
        isPlaying = false
        intensity = 0.0
    }
}
