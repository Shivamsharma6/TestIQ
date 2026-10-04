import SwiftUI

@main
struct TestIQApp: App {
    @State private var state = AppState()

    init() {
        SoundEngine.shared.isEnabled = ProgressStore.shared.load().soundEnabled
        SoundEngine.shared.prepare()
        HapticsEngine.shared.prepare()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}