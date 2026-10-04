import SwiftUI

struct LevelIntroView: View {
    let level: LevelDefinition
    @Environment(AppState.self) private var app
    private var accent: Color { Theme.accent(named: self.level.accentName) }

    var body: some View {
        ZStack {
            ArcadeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Button { self.app.goHome() } label: {
                        Label("The ascent", systemImage: "arrow.left")
                            .font(.app(.subheadline, size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 9) {
                            ArcadeEyebrow(text: "Floor \(self.level.id) / \(LevelCatalog.count)", tint: self.accent)
                            Text(self.level.name)
                                .font(.app(.largeTitle, size: 34, weight: .black))
                                .foregroundStyle(Theme.textPrimary)
                            Text(self.level.tagline)
                                .font(.app(.subheadline, size: 15))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        ArcadeFloorEmblem(symbol: self.level.domain.symbol, tint: self.accent, size: 66)
                    }
                    GlassCard(padding: 20, tint: self.accent) {
                        VStack(alignment: .leading, spacing: 18) {
                            Label(self.level.isAdaptive ? "Mixed skills" : self.level.domain.title,
                                  systemImage: self.level.domain.symbol)
                                .font(.app(.headline, size: 17, weight: .bold))
                                .foregroundStyle(self.accent)
                            Text(self.level.domain.blurb)
                                .font(.app(.subheadline, size: 14))
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 12) {
                                StatTile(value: "\(self.level.itemCount)", label: "Puzzles")
                                StatTile(value: "\(self.level.hintCharges)", label: "Hints", tint: Theme.hint)
                                StatTile(value: "\(Int((self.level.starGate * 100).rounded()))%", label: "To clear", tint: self.accent)
                            }
                        }
                    }
                    if let best = self.app.progress.personalBestScore(for: self.level.id) {
                        GlassCard(padding: 18, tint: Theme.violet) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    ArcadeEyebrow(text: "The score to chase", tint: Theme.violet)
                                    Text("\(best.formatted()) points")
                                        .font(.app(.title2, size: 25, weight: .heavy))
                                        .foregroundStyle(Theme.textPrimary)
                                }
                                Spacer()
                                StarRating(stars: self.app.progress.stars(for: self.level.id), size: 18)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        self.rule("timer", "Each puzzle has its own timer. Warm-ups are untimed.")
                        self.rule("flame.fill", "Correct answers build a combo, up to ×5 points.")
                        self.rule("lightbulb.fill", "Hints teach a technique and reduce the points earned.")
                        self.rule("star.fill", "Clear with accuracy. Earn the third star with accuracy and pace.")
                    }
                    if self.level.isAdaptive {
                        Text("This round’s starting difficulty uses your previous results. The puzzle set is ready before you begin.")
                            .font(.app(.footnote, size: 13))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    PrimaryButton(title: "Let’s play", systemImage: "play.fill", tint: self.accent) {
                        self.app.start(self.level.id)
                    }
                }
                .padding(Theme.Metrics.gutter)
                .padding(.bottom, 20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func rule(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(self.accent).frame(width: 22)
            Text(text).font(.app(.subheadline, size: 14)).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
