import SwiftUI

struct GameView: View {
    let level: LevelDefinition
    let attempt: Int
    @Environment(AppState.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: GameViewModel?
    @State private var shakeOffset: CGFloat = 0
    private var accent: Color { Theme.accent(named: self.level.accentName) }

    var body: some View {
        ZStack {
            ArcadeBackdrop()
            if let model {
                if case .warmup(let lesson) = model.phase {
                    VStack(spacing: 0) {
                        HStack {
                            Button { self.leave(model) } label: {
                                Image(systemName: "xmark")
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .accessibilityLabel("Leave round")
                            Spacer()
                            ArcadeEyebrow(text: "Floor \(self.level.id)", tint: self.accent)
                            Spacer()
                            Color.clear.frame(width: 44, height: 44)
                        }
                        .padding(.horizontal, Theme.Metrics.gutter)
                        InteractionWarmupView(lesson: lesson, accent: self.accent) {
                            model.completeWarmup()
                        }
                        .id(lesson.rawValue)
                    }
                } else {
                    self.content(model)
                }
            } else {
                ProgressView().tint(self.accent)
            }
        }
        .task {
            guard self.model == nil else { return }
            let fresh = GameViewModel(
                level: self.level, attempt: self.attempt, ability: self.app.currentAbility(),
                learnedInteractions: self.app.progress.learnedInteractions,
                onInteractionLearned: { self.app.markInteractionLearned($0) }
            )
            self.model = fresh
            fresh.start()
            if self.scenePhase != .active || self.app.saveWarning != nil { fresh.suspend() }
        }
        .onDisappear { self.model?.stop() }
        .onChange(of: self.scenePhase) { _, phase in
            if phase == .active && self.app.saveWarning == nil {
                self.model?.resume()
            } else {
                self.model?.suspend()
            }
        }
        .onChange(of: self.app.saveWarning) { _, warning in
            if warning == nil && self.scenePhase == .active {
                self.model?.resume()
            } else {
                self.model?.suspend()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quitRun)) { _ in
            if let model = self.model { self.leave(model) }
        }
        .onChange(of: self.model?.result?.id) { _, id in
            guard id != nil, let result = self.model?.result else { return }
            self.app.finish(result)
        }
    }

    private func leave(_ model: GameViewModel) {
        model.stop()
        self.app.goHome()
    }

    private func content(_ model: GameViewModel) -> some View {
        VStack(spacing: 0) {
            HUDView(level: self.level, model: model, accent: self.accent)
                .padding(.horizontal, Theme.Metrics.gutter)
                .padding(.top, 8)
                .padding(.bottom, 18)
            ScrollView {
                VStack(spacing: 22) {
                    self.promptBlock(model)
                    // EchoInteraction owns the live grid. A second passive grid is confusing.
                    if model.puzzle.archetype != .echo {
                        StimulusView(stimulus: model.puzzle.stimulus, accent: self.accent)
                            .frame(maxWidth: .infinity)
                    }
                    InteractionView(puzzle: model.puzzle, model: model, accent: self.accent,
                                    revealedCorrect: model.lastAnswerCorrect == false)
                    self.hintBlock(model)
                }
                .padding(.horizontal, Theme.Metrics.gutter)
                .padding(.bottom, 24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { self.feedbackBar(model) }
        .overlay(alignment: .top) {
            ParticleBurst(token: model.burstToken, tint: self.accent, origin: .init(x: 0.5, y: 0.32))
                .frame(height: 240)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .offset(x: self.shakeOffset)
        .onChange(of: model.shakeToken) { _, token in
            guard token > 0, Motion.enabled else { return }
            withAnimation(.easeInOut(duration: 0.06)) { self.shakeOffset = -6 }
            withAnimation(.easeInOut(duration: 0.08).delay(0.06)) { self.shakeOffset = 5 }
            withAnimation(.easeOut(duration: 0.12).delay(0.14)) { self.shakeOffset = 0 }
        }
    }

    private func promptBlock(_ model: GameViewModel) -> some View {
        VStack(spacing: 10) {
            Label(model.puzzle.kind.title.uppercased(), systemImage: model.puzzle.domain.symbol)
                .font(.app(.caption, size: 11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(self.accent)
            Text(model.puzzle.prompt)
                .font(.app(.title2, size: 24, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle = model.puzzle.subtitle {
                Text(subtitle)
                    .font(.app(.footnote, size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func hintBlock(_ model: GameViewModel) -> some View {
        if model.showHint && model.phase == .awaitingAnswer {
            GlassCard(padding: 14, tint: Theme.hint) {
                Label(model.puzzle.hint, systemImage: "lightbulb.fill")
                    .font(.app(.subheadline, size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if model.canUndo && model.phase == .awaitingAnswer {
            QuietButton(title: "Undo last move", systemImage: "arrow.uturn.backward") { model.undoLastTap() }
        }
    }

    @ViewBuilder
    private func feedbackBar(_ model: GameViewModel) -> some View {
        if case .showingFeedback(let correct) = model.phase {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: correct ? "checkmark.circle.fill" : "arrow.clockwise.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(self.reaction(model, correct: correct))
                            .font(.app(.headline, size: 18, weight: .heavy))
                        Text(correct ? "Correct · +\(model.earnedPoints) points" : model.lastAnswerTimedOut ? "Time’s up. Next puzzle, fresh start." : "Missed this one. Here’s a move to try.")
                            .font(.app(.footnote, size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                    if correct && model.streak >= 2 {
                        Text("×\(model.comboMultiplier)")
                            .font(.mono(24, weight: .black))
                    }
                }
                .foregroundStyle(correct ? Theme.correct : Theme.incorrect)
                .accessibilityElement(children: .combine)

                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("THE MOVE")
                            .font(.app(.caption2, size: 10, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(self.accent)
                        Text(model.puzzle.hint)
                            .font(.app(.footnote, size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 80)
                .scrollBounceBehavior(.basedOnSize)
                PrimaryButton(title: model.isLastItem ? "See this round" : "Next puzzle",
                              systemImage: model.isLastItem ? "flag.checkered" : "arrow.right") {
                    model.advance()
                }
            }
            .padding(18)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .background(Theme.surface)
            .overlay(alignment: .top) { Rectangle().fill(correct ? Theme.correct : Theme.incorrect).frame(height: 2) }
            .transition(Motion.enabled ? .move(edge: .bottom).combined(with: .opacity) : .opacity)
        }
    }

    private func reaction(_ model: GameViewModel, correct: Bool) -> String {
        guard correct else { return model.lastAnswerTimedOut ? "The clock won that one." : "Plot twist." }
        switch model.streak {
        case 2: return "Two’s a streak."
        case 3: return "Now we’re cooking."
        case 5: return "Maximum combo. Mildly unstoppable."
        case 6...: return "Your record is getting nervous."
        default: return "Nailed it."
        }
    }
}
