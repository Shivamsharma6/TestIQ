import SwiftUI

/// One coaching card: the observation, the technique, the drill, and the mistake to avoid.
///
/// The four-part structure is deliberate and enforced by the model. A card that cannot
/// fill in `evidence`, `technique`, `drill` and `pitfall` has nothing useful to say and
/// does not get built.
struct CoachingCardView: View {
    @Environment(AppState.self) private var app
    let tip: CoachingTip
    var accent: Color = Theme.accent

    @State private var expanded = false

    var body: some View {
        GlassCard(padding: 16, tint: self.tint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: self.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(self.tint)
                        .frame(width: 30, height: 30)
                        .background { Circle().fill(self.tint.opacity(0.14)) }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(self.tip.title)
                            .font(.app(.headline, size: 15, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(self.tip.evidence)
                            .font(.app(.footnote, size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                section(
                    symbol: "wand.and.stars",
                    title: "Technique",
                    body: self.tip.technique,
                    color: Theme.correct
                )

                if self.expanded {
                    section(
                        symbol: "figure.walk.motion",
                        title: "Do this",
                        body: self.tip.drill,
                        color: self.accent
                    )
                }

                section(
                    symbol: "exclamationmark.triangle.fill",
                    title: "Watch for",
                    body: self.tip.pitfall,
                    color: Theme.incorrect
                )

                HStack(spacing: 10) {
                    Button {
                        withAnimation(Motion.enabled ? Motion.gentle : nil) { self.expanded.toggle() }
                        HapticsEngine.shared.tap()
                    } label: {
                        Label(
                            self.expanded ? "Hide the drill" : "Show me the drill",
                            systemImage: self.expanded ? "chevron.up" : "chevron.down"
                        )
                        .font(.app(.footnote, size: 13, weight: .semibold))
                        .foregroundStyle(self.accent)
                        .frame(minHeight: Theme.Metrics.minTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(self.expanded ? "Collapses the practice drill" : "Expands a specific practice drill")

                    Spacer()

                }

                if let levelID = self.tip.suggestedLevelID,
                   let level = LevelCatalog.level(levelID) {
                    if self.app.progress.isUnlocked(levelID) {
                        QuietButton(title: "Practice floor \(levelID): \(level.name)", systemImage: "play.fill") {
                            self.app.open(levelID)
                        }
                        .accessibilityHint("Opens this floor’s introduction so you can practice the technique")
                    } else {
                        Label("Clear floor \(levelID - 1) to unlock this practice floor.", systemImage: "lock.fill")
                            .font(.app(.footnote, size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func section(symbol: String, title: String, body text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text(title.uppercased())
                    .font(.app(.caption2, size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(color)
            }

            Text(text)
                .font(.app(.footnote, size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.07))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(text)")
    }

    private var symbol: String {
        switch self.tip.kind {
        case .domainWeakness: return "chart.bar.xaxis"
        case .errorCluster: return "exclamationmark.bubble"
        case .pacing: return "speedometer"
        }
    }

    private var tint: Color {
        switch self.tip.kind {
        case .domainWeakness: return Theme.accent
        case .errorCluster: return Theme.hint
        case .pacing: return Theme.incorrect
        }
    }
}
