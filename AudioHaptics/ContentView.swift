import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @StateObject private var vm = HapticPlayerViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Audio → Haptics")
                .font(.title2)
                .bold()

            HStack {
                Text("Intensity:")
                Spacer()
                Text(String(format: "%.2f", vm.intensity))
                    .monospacedDigit()
            }

            ProgressView(value: vm.intensity)
                .progressViewStyle(.linear)

            Toggle("Haptics only (mute audio)", isOn: $vm.hapticsOnly)

            VStack(alignment: .leading, spacing: 6) {
                Text("Gain: \(String(format: "%.2f", vm.gain))")
                Slider(value: $vm.gain, in: 0.2...2.5)
            }

            HStack(spacing: 12) {
                Button(vm.isRunning ? "Stop" : "Start") {
                    if vm.isRunning { vm.stop() } else { vm.startWithBundledFile() }
                }
                .buttonStyle(.borderedProminent)

                Button("Test") {
                    vm.test()
                }
                .buttonStyle(.bordered)
            }

            Text("Важно: добавь файл **song.mp3** в проект (Copy Bundle Resources).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
}
