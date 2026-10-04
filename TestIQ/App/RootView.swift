import SwiftUI

/// Top-level navigation. A stack rather than a tab bar, because the flow is linear:
/// choose a floor, play it, see the result, move up.
struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        ZStack {
            Theme.background.ignoresSafeArea()

            switch state.route {
            case .home:
                HomeView()
                    .transition(self.slide(.trailing))

            case .levelIntro(let levelID):
                if let level = LevelCatalog.level(levelID) {
                    LevelIntroView(level: level)
                        .transition(self.slide(.bottom))
                }

            case .game(let levelID, let attempt):
                if let level = LevelCatalog.level(levelID) {
                    GameView(level: level, attempt: attempt)
                        .transition(self.slide(.bottom))
                }

            case .levelComplete(let levelID):
                LevelCompleteView(levelID: levelID)
                    .transition(self.slide(.bottom))

            case .report:
                ReportView()
                    .transition(self.slide(.bottom))
            }
        }
        .animation(Motion.enabled ? Motion.settle : nil, value: state.route)
        .environment(\.colorScheme, .dark)
        .alert("Progress needs attention", isPresented: Binding(
            get: { state.saveWarning != nil },
            set: { if !$0 { state.saveWarning = nil } }
        )) {
            Button("OK") { state.saveWarning = nil }
        } message: {
            Text(state.saveWarning ?? "")
        }
    }

    private func slide(_ edge: Edge) -> AnyTransition {
        Motion.enabled
            ? .asymmetric(insertion: .move(edge: edge), removal: .opacity)
            : .opacity
    }
}

#Preview {
    RootView().environment(AppState(store: ProgressStore(url: URL(fileURLWithPath: "/dev/null"))))
}
