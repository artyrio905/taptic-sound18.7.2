import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @StateObject private var vm = HapticPlayerViewModel()
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 14) {
            Text("Music → Haptics")
                .font(.title2).bold()

            HStack {
                Text("Intensity:")
                Spacer()
                Text(String(format: "%.2f", vm.intensity)).monospacedDigit()
            }
            ProgressView(value: vm.intensity)
                .progressViewStyle(.linear)

            Toggle("Haptics only (mute audio)", isOn: $vm.hapticsOnly)

            VStack(alignment: .leading, spacing: 6) {
                Text("Gain: \(String(format: "%.2f", vm.gain))")
                Slider(value: $vm.gain, in: 0.2...3.0)
            }

            VStack(spacing: 10) {
                Button(vm.pickedURL == nil ? "Выбрать MP3" : "Выбран: \(vm.pickedURL!.lastPathComponent)") {
                    showPicker = true
                }
                .buttonStyle(.bordered)

                HStack(spacing: 12) {
                    Button(vm.isRunning ? "Stop" : "Start") {
                        if vm.isRunning { vm.stop() } else { vm.start() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.pickedURL == nil)

                    Button("Test") { vm.test() }
                        .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showPicker) {
            MP3DocumentPicker(
                onPick: { url in
                    vm.pickedURL = url
                    showPicker = false
                },
                onCancel: {
                    showPicker = false
                }
            )
        }
    }
}
