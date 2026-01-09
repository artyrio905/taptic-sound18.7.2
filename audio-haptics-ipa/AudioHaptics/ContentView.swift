import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var vm: HapticPlayerViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Audio → Taptic")
                .font(.headline)

            if let url = vm.audioURL {
                Text(url.lastPathComponent)
                    .font(.subheadline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Text("Import an audio file (mp3/m4a/wav…) or Share it сюда.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button("Import") { vm.showImporter = true }
                    .buttonStyle(.bordered)

                Button("Play") { vm.play() }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.audioURL == nil || vm.isPlaying)

                Button("Stop") { vm.stop() }
                    .buttonStyle(.bordered)
                    .disabled(!vm.isPlaying)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Haptic intensity: \(vm.intensity, specifier: "%.2f")")

                Slider(value: $vm.userGain, in: 0.5...3.0, step: 0.05) {
                    Text("Gain")
                }
                Text("Gain: \(vm.userGain, specifier: "%.2f") (stronger vibro)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $vm.showImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            vm.handleImport(result)
        }
        .onDisappear { vm.stop() }
    }
}
