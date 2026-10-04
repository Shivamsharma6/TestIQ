import SwiftUI

/// The main play screen for one floor.
///
/// Layout is fixed from the top down — HUD, prompt, stimulus, interaction — because the
/// interaction area must never move as the stimulus changes size. That stability is what
/// makes the rhythm of repeated items feel automatic.
struct GameView: View {
    let level: LevelDefinition
    let attempt: Int

    @Environment(AppState.self) private var app
    @State private var model: GameViewModel?
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var isScrollFocused: Bool

    private var accent: Color { Theme.accent(named: self.level.accentName) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let model {
                content(model)
            } else {
                ProgressView().tint(self.accent)
            }
        }
        .task {
            guard self.model == nil else { return }
            let fresh = GameViewModel(level: self.level, attempt: self.attempt, ability: self.app.currentAbility())
            fresh.start()
            self.model = fresh
        }
        .onDisappear { self.model?.stop() }
        .onReceive(NotificationCenter.default.publisher(for: .quitRun)) { _ in
            self.model?.stop()
            self.app.goHome()
        }
        .onChange(of: self.model?.result?.id) { _, id in
            guard id != nil, let result = self.model?.result else { return }
            // The result is handed to the store exactly once, when the run ends.
            self.app.finish(result)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ model: GameViewModel) -> some View {
        VStack(spacing: 0) {
            HUDView(level: self.level, model: model, accent: self.accent)
                .padding(.horizontal, Theme.Metrics.gutter)
                .padding(.top, 6)
                .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 18) {
                    promptBlock(model)
                    StimulusView(stimulus: model.puzzle.stimulus, accent: self.accent)
                        .padding(model.puzzle.archetype == .echo ? 0 : 6)
                        .frame(maxWidth: .infinity)

                    InteractionView(
                        puzzle: model.puzzle,
                        model: model,
                        accent: self.accent,
                        revealedCorrect: model.lastAnswerCorrect == false
                    )
                    .padding(.top, 2)

                    hintBlock(model)
                }
                .padding(.horizontal, Theme.Metrics.gutter)
                .padding(.bottom, 150)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)

            feedbackBar(model)
        }
        .overlay(alignment: .top) {
            ParticleBurst(
                token: model.burstToken,
                tint: Theme.correct,
                origin: .init(x: 0.5, y: 0.32)
            )
            .frame(height: 260)
            .allowsHitTesting(false)
        }
        .offset(x: self.shakeOffset)
        .onChange(of: model.shakeToken) { _, token in
            guard token > 0, Motion.enabled else { return }
            withAnimation(.easeInOut(duration: 0.06)) { self.shakeOffset = -10 }
            withAnimation(.easeInOut(duration: 0.08).delay(0.06)) { self.shakeOffset = 8 }
            withAnimation(.easeOut(duration: 0.12).delay(0.14)) { self.shakeOffset = 0 }
        }
    }

    // MARK: - Pieces

    private func promptBlock(_ model: GameViewModel) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: model.puzzle.kind.domain.symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(self.accent)
                Text(model.puzzle.kind.title.uppercased())
                    .font(.app(.caption2, size: 11, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(self.accent)
            }

            Text(model.puzzle.prompt)
                .font(.app(.title2, size: 21, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle = model.puzzle.subtitle {
                Text(subtitle)
                    .font(.app(.footnote, size: 13, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func hintBlock(_ model: GameViewModel) -> some View {
        if model.showHint {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.hint)

                Text(model.puzzle.hint)
                    .font(.app(.subheadline, size: 14, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.hint.opacity(0.10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.hint.opacity(0.28), lineWidth: 1)
                    }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Hint: \(model.puzzle.hint)")
        } else if model.canUndo, model.phase == .awaitingAnswer {
            QuietButton(title: "Undo", systemImage: "arrow.uturn.backward") {
                model.undoLastTap()
            }
        }
    }

    @ViewBuilder
    private func feedbackBar(_ model: GameViewModel) -> some View {
        if case .showingFeedback(let correct) = model.phase {
            VStack {
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    HStack(spacing: 9) {
                        Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(correct ? Theme.correct : Theme.incorrect)

                        Text(correct ? "Correct" : "Not this time")
                            .font(.app(.headline, size: 17, weight: .bold))
                            .foregroundStyle(correct ? Theme.correct : Theme.incorrect)

                        Spacer(minLength: 0)

                        if correct, model.comboMultiplier > 1 {
                            Text("+\(model.comboMultiplier)× streak")
                                .font(.mono(12, weight: .bold))
                                .foregroundStyle(Theme.incorrect)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    PrimaryButton(
                        title: model.isLastItem ? "See results" : "Next",
                        systemImage: model.isLastItem ? "flag.checkered" : "arrow.right"
                    ) {
                        model.advance()
                    }
                }
                .padding(16)
                .background {
                    UnevenRoundedRectangle(
                        topLeadingRadius: Theme.Metrics.corner,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: Theme.Metrics.corner,
                        style: .continuous
                    )
                    .fill(Theme.surface.opacity(0.97))
                    .ignoresSafeArea(edges: .bottom)
                    .overlay {
                        UnevenRoundedRectangle(
                            topLeadingRadius: Theme.Metrics.corner,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: Theme.Metrics.corner,
                            style: .continuous
                        )
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                        .ignoresSafeArea(edges: .bottom)
                    }
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(correct ? Theme.correct : Theme.incorrect)
                        .frame(height: 2)
                }
            }
            .transition(.move(edge: .bottom))
            .ignoresSafeArea(edges: .bottom)
        }
    }
}