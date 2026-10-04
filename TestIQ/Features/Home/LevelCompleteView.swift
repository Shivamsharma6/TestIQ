import SwiftUI

/// What happened on a floor: stars, score, and where the answers went.
///
/// The accuracy-by-item strip is deliberate — it shows the shape of the run, so a player
/// can see at a glance whether they front-loaded well, tailed off, or hit a wall halfway.
struct LevelCompleteView: View {
    let levelID: Int
    @Environment(AppState.self) private var app
    @State private var showStars = false

    private var level: LevelDefinition? { LevelCatalog.level(self.levelID) }
    private var progress: PlayerProgress { self.app.progress }
    private var result: LevelResult? { self.progress.levelResults[self.levelID] }

    private var accent: Color {
        Theme.accent(named: self.level?.accentName ?? "indigo")
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ConfettiView(isActive: self.result?.isCleared ?? false)

            if let level, let result {
                ScrollView {
                    VStack(spacing: 22) {
                        titleBlock(level: level, result: result)
                        starsBlock(result: result)
                        statBlock(result: result)
                        itemStrip(result: result)
                        nextBlock(level: level, result: result)
                    }
                    .padding(Theme.Metrics.gutter)
                    .padding(.top, 20)
                }
            } else {
                ProgressView().tint(self.accent)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard self.result != nil else { return }
            // Stars land one at a time so the reward reads as three separate events.
            withAnimation(Motion.enabled ? .spring(response: 0.4, dampingFraction: 0.55) : nil) {
                self.showStars = true
            }
        }
    }

    // MARK: - Pieces

    private func titleBlock(level: LevelDefinition, result: LevelResult) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill((result.isCleared ? Theme.correct : Theme.incorrect).opacity(0.15))
                    .frame(width: 96, height: 96)
                Image(systemName: result.isCleared ? "checkmark.seal.fill" : "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(result.isCleared ? Theme.correct : Theme.incorrect)
            }
            .scaleEffect(Motion.enabled ? 1 : 1)
            .appearIn(0)

            Text(result.isCleared ? "Floor \(level.id) cleared" : "Floor \(level.id) not yet cleared")
                .font(.app(.title, size: 26, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            Text(result.isCleared ? level.name : "You need \(Int(level.starGate * 100))% correct to unlock the next floor.")
                .font(.app(.subheadline, size: 14, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func starsBlock(result: LevelResult) -> some View {
        HStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < result.stars ? "star.fill" : "star")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(index < result.stars ? Theme.hint : Theme.textTertiary.opacity(0.30))
                    .scaleEffect(Motion.enabled && self.showStars && index < result.stars ? 1 : 0.6)
                    .opacity(Motion.enabled && self.showStars ? 1 : 0)
                    .animation(
                        Motion.enabled
                            ? .spring(response: 0.42, dampingFraction: 0.5)
                                .delay(Double(index) * 0.16) : nil,
                        value: self.showStars
                    )
            }
        }
        .frame(height: 48)
        .accessibilityElement()
        .accessibilityLabel("\(result.stars) of 3 stars")
    }

    private func statBlock(result: LevelResult) -> some View {
        GlassCard(padding: 16) {
            HStack(spacing: 0) {
                StatTile(value: "\(Int(result.score))", label: "Score", tint: self.accent)
                Divider().frame(height: 34).overlay(Theme.stroke)
                StatTile(value: "\(result.correctCount)/\(result.items.count)", label: "Correct",
                         tint: result.accuracy >= 0.7 ? Theme.correct : Theme.hint)
                Divider().frame(height: 34).overlay(Theme.stroke)
                StatTile(value: "×\(min(5, max(1, result.bestStreak)))", label: "Best streak",
                         tint: Theme.incorrect)
            }
        }
    }

    /// One tick per item, in order, coloured by correctness.
    private func itemStrip(result: LevelResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(
                title: "Item by item",
                subtitle: "\(result.items.count) items · \(Int(result.duration))s of thinking",
                symbol: "list.bullet.rectangle"
            )

            HStack(spacing: 5) {
                ForEach(Array(result.items.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(item.correct ? Theme.correct.opacity(0.85) : Theme.incorrect.opacity(0.85))
                            .frame(height: 26)
                            .overlay {
                                if item.hintsUsed > 0 {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.6))
                                }
                            }
                        Text("\(index + 1)")
                            .font(.mono(9, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .accessibilityElement()
                    .accessibilityLabel("Item \(index + 1), \(item.kind.title)")
                    .accessibilityValue(
                        item.correct
                            ? "correct in \(Int(item.elapsed)) seconds\(item.hintsUsed > 0 ? ", used a hint" : "")"
                            : "incorrect\(item.timedOut ? ", ran out of time" : "")"
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func nextBlock(level: LevelDefinition, result: LevelResult) -> some View {
        VStack(spacing: 10) {
            if result.isCleared, level.id < LevelCatalog.finalLevelID {
                let next = LevelCatalog.level(level.id + 1)
                PrimaryButton(
                    title: next.map { "Climb to \($0.name)" } ?? "Continue",
                    systemImage: "arrow.up",
                    tint: self.accent
                ) {
                    self.app.open(level.id + 1)
                }
            } else if result.isCleared, level.id == LevelCatalog.finalLevelID {
                PrimaryButton(title: "See your assessment", systemImage: "chart.dots.scatter") {
                    self.app.openReport()
                }
            } else {
                PrimaryButton(title: "Try this floor again", systemImage: "arrow.clockwise", tint: Theme.hint) {
                    self.app.start(level.id)
                }
            }

            if result.isCleared {
                QuietButton(title: "Your assessment", systemImage: "chart.dots.scatter") {
                    self.app.openReport()
                }
            }

            QuietButton(title: "Back to the path", systemImage: "chevron.down") {
                self.app.goHome()
            }
        }
    }
}