import SwiftUI

struct LevelCompleteView: View {
    let levelID: Int
    @Environment(AppState.self) private var app
    @State private var showStars = false
    private var level: LevelDefinition? { LevelCatalog.level(self.levelID) }
    private var result: LevelResult? {
        if let latest = self.app.lastResult, latest.levelID == self.levelID { return latest }
        return self.app.progress.latestResult(for: self.levelID)
    }
    private var isNewRecord: Bool {
        guard let result, let previous = self.app.previousBestScore else { return false }
        return result.score > previous
    }
    private var accent: Color { Theme.accent(named: self.level?.accentName ?? "mint") }

    var body: some View {
        ZStack {
            ArcadeBackdrop()
            if let level, let result {
                ScrollView {
                    VStack(spacing: 22) {
                        ArcadeEyebrow(text: "Round complete · Floor \(level.id)", tint: self.accent)
                        ArcadeFloorEmblem(symbol: self.isNewRecord ? "trophy.fill" : result.isCleared ? "flag.checkered" : "arrow.clockwise", tint: self.accent, size: 84)
                        VStack(spacing: 8) {
                            Text(self.isNewRecord ? "New personal best." : result.isCleared ? "Floor cleared.\nOnward!" : "Rematch material.")
                                .font(.app(.largeTitle, size: 34, weight: .black))
                                .foregroundStyle(Theme.textPrimary)
                                .multilineTextAlignment(.center)
                            Text(result.isCleared ? level.name : "\(Int((level.starGate * 100).rounded()))% accuracy clears this floor. You’ve got another shot.")
                                .font(.app(.subheadline, size: 14))
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        HStack(spacing: 16) {
                            ForEach(0..<3, id: \.self) { index in
                                Image(systemName: index < result.stars ? "star.fill" : "star")
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundStyle(index < result.stars ? Theme.hint : Theme.textTertiary.opacity(0.4))
                                    .scaleEffect(Motion.enabled && !self.showStars ? 0.65 : 1)
                                    .opacity(!Motion.enabled || self.showStars ? 1 : 0)
                                    .animation(Motion.enabled ? Motion.bouncy.delay(Double(index) * 0.12) : nil, value: self.showStars)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("This round: \(result.stars) of 3 stars")
                        self.scoreCard(result)
                        GlassCard(padding: 18) {
                            HStack(alignment: .top, spacing: 14) {
                                StatTile(value: "\(result.correctCount)/\(result.items.count)", label: "Correct", tint: Theme.correct)
                                StatTile(value: "\(result.bestStreak)", label: "Best streak", tint: Theme.violet)
                                StatTile(value: "\(result.items.reduce(0) { $0 + $1.hintsUsed })", label: "Hints used", tint: Theme.hint)
                            }
                        }
                        self.itemStrip(result)
                        self.actions(level, result)
                    }
                    .padding(Theme.Metrics.gutter)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            if self.isNewRecord || self.result?.isCleared == true {
                ArcadeRecordCelebration().allowsHitTesting(false)
            }
        }
        .onAppear {
            self.showStars = true
            if self.isNewRecord {
                SoundEngine.shared.personalRecord()
                HapticsEngine.shared.success()
            }
        }
    }

    private func scoreCard(_ result: LevelResult) -> some View {
        GlassCard(padding: 22, tint: self.accent) {
            VStack(alignment: .leading, spacing: 16) {
                ArcadeEyebrow(text: "This round", tint: self.accent)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(result.score.formatted()).font(.mono(48, weight: .black)).foregroundStyle(Theme.textPrimary)
                    Text("PTS").font(.app(.caption, size: 12, weight: .heavy)).foregroundStyle(self.accent)
                }
                Divider().overlay(Theme.stroke)
                if let previous = self.app.previousBestScore {
                    HStack {
                        Text(self.isNewRecord ? "Previous best" : "Personal best")
                        Spacer()
                        Text(previous.formatted() + " pts").fontWeight(.bold)
                    }
                    .font(.app(.subheadline, size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    let difference = result.score - previous
                    Text(difference > 0 ? "+\(difference.formatted()) points. Your old record had a good run." : difference == 0 ? "Record matched. The next point is yours to chase." : "\((-difference).formatted()) points to your record. Try the technique, then take another run.")
                        .font(.app(.footnote, size: 13))
                        .foregroundStyle(self.accent)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("First score on the board. Next time, you’re the one to beat.")
                        .font(.app(.subheadline, size: 14))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func itemStrip(_ result: LevelResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "The round, move by move", subtitle: "\(Int(result.duration.rounded())) seconds of answering")
            HStack(spacing: 5) {
                ForEach(Array(result.items.enumerated()), id: \.offset) { index, item in
                    Image(systemName: item.correct ? "checkmark" : item.timedOut ? "timer" : "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(item.correct ? Theme.correct : Theme.incorrect)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(item.correct ? Theme.correct.opacity(0.10) : Theme.incorrect.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
                        .accessibilityLabel("Puzzle \(index + 1), \(item.correct ? "correct" : item.timedOut ? "time ran out" : "incorrect")")
                }
            }
        }
    }

    private func actions(_ level: LevelDefinition, _ result: LevelResult) -> some View {
        VStack(spacing: 12) {
            if result.isCleared && level.id < LevelCatalog.finalLevelID {
                PrimaryButton(title: "Next floor", systemImage: "arrow.up", tint: self.accent) {
                    self.app.open(level.id + 1)
                }
                QuietButton(title: "Chase my record", systemImage: "arrow.clockwise") { self.app.start(level.id) }
            } else {
                PrimaryButton(title: "Play again", systemImage: "arrow.clockwise", tint: self.accent) { self.app.start(level.id) }
            }
            QuietButton(title: "Progress & my next move", systemImage: "chart.xyaxis.line") { self.app.openReport() }
            QuietButton(title: "Back to the ascent", systemImage: "arrow.left") { self.app.goHome() }
        }
    }
}
