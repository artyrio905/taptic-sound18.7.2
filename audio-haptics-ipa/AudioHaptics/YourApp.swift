import SwiftUI

@main
struct YourApp: App {
    @StateObject private var vm = HapticPlayerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .onOpenURL { url in
                    vm.handleIncomingURL(url)
                }
        }
    }
}
