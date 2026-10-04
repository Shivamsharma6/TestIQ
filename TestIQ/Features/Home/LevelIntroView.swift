import SwiftUI

/// Pre-flight screen for a floor: what it tests, how long it takes, what you earned last
/// time. Showing this before the clock starts is what makes the per-item time limit feel
/// fair instead of arbitrary.
struct LevelIntroView: View {
    let level: LevelDefinition
    @Environment(AppState.self) private var app

    private var accent: Color { Theme.accent(named: self.level.accentName) }
    private var progress: PlayerProgress { self.app.progress }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    header

                    GlassCard(tint: self.accent) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label(self.level.domain.title, systemImage: self.level.domain.symbol)
                                    .font(.app(.headline, size: 15, weight: .bold))
                                    .foregroundStyle(self.accent)
                                Spacer()
                                if self.progress.stars(for: self.level.id) > 0 {
                                    StarRating(stars: self.progress.stars(for: self.level.id), size: 13)
                                }
                            }

                            Text(self.level.domain.blurb)
                                .font(.app(.subheadline, size: 14, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Divider().overlay(Theme.stroke)

                            HStack(spacing: 0) {
                                StatTile(value: "\(self.level.itemCount)", label: "Items")
                                Divider().frame(height: 32).overlay(Theme.stroke)
                                StatTile(value: "\(Int(self.level.duration))s", label: "Total time")
                                Divider().frame(height: 32).overlay(Theme.stroke)
                                StatTile(value: "\(self.level.hintCharges)", label: "Hints", tint: Theme.hint)
                            }
                        }
                    }

                    difficultyRow

                    if self.level.isAdaptive {
                        GlassCard(tint: Theme.correct) {
                            Label(
                                "This floor adapts. Answer a few and the difficulty shifts towards where you actually are.",
                                systemImage: "arrow.triangle.2.circlepath"
                            )
                            .font(.app(.footnote, size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    rulesList

                    Spacer(minLength: 20)

                    PrimaryButton(title: "Ascend", systemImage: "arrow.up", tint: self.accent) {
                        self.app.start(self.level.id)
                    }

                    QuietButton(title: "Back to the path", systemImage: "chevron.down") {
                        self.app.goHome()
                    }
                }
                .padding(Theme.Metrics.gutter)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("FLOOR \(self.level.id) OF \(LevelCatalog.count)")
                .font(.app(.caption2, size: 11, weight: .heavy))
                .tracking(1.8)
                .foregroundStyle(self.accent)

            Text(self.level.name)
                .font(.app(.largeTitle, size: 34, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)

            Text(self.level.tagline)
                .font(.app(.subheadline, size: 15, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.top, 24)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Shows the ramp this floor will actually walk, which is the honest version of a
    /// difficulty badge.
    private var difficultyRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DIFFICULTY RAMP")
                    .font(.app(.caption2, size: 10, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text(String(format: "%.1f → %.1f", self.level.openingTheta, self.level.closingTheta))
                    .font(.mono(12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.correct, Theme.hint, Theme.incorrect],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * 0.92)
                }
            }
            .frame(height: 7)
            .accessibilityElement()
            .accessibilityLabel("Difficulty rises across this floor")
            .accessibilityValue("From \(String(format: "%.1f", self.level.openingTheta)) to \(String(format: "%.1f", self.level.closingTheta))")
        }
    }

    private var rulesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ruleRow("clock", "Every item has its own timer. Running it out scores the same as answering wrong.")
            ruleRow("bolt.fill", "Consecutive correct answers build a multiplier, up to ×5.")
            ruleRow("lightbulb.fill", "Hints show a technique, never the answer — and cost you score.")
            ruleRow("star.fill", "Three stars need both accuracy and pace.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ruleRow(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(self.accent)
                .frame(width: 22, height: 22)
                .background { Circle().fill(self.accent.opacity(0.14)) }

            Text(text)
                .font(.app(.footnote, size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}