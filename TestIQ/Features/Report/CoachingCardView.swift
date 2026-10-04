import SwiftUI

/// One coaching card: the observation, the technique, the drill, and the mistake to avoid.
///
/// The four-part structure is deliberate and enforced by the model. A card that cannot
/// fill in `evidence`, `technique`, `drill` and `pitfall` has nothing useful to say and
/// does not get built.
struct CoachingCardView: View {
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
                    title: "Avoid",
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
                        .frame(minHeight: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(self.expanded ? "Collapses the practice drill" : "Expands a specific practice drill")

                    Spacer()

                    if let levelID = self.tip.suggestedLevelID {
                        Text("Replay floor \(levelID)")
                            .font(.app(.caption2, size: 11, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                            .accessibilityHidden(true)
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

/// Per-floor accuracy, so a player can see where the ascent actually got hard for them.
struct LevelBreakdownView: View {
    let breakdown: [LevelBreakdown]
    let starTotal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(self.breakdown) { floor in
                HStack(spacing: 12) {
                    Text("\(floor.levelID)")
                        .font(.mono(12, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(floor.name)
                            .font(.app(.subheadline, size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(floor.itemCount) items · \(floor.score) points")
                            .font(.app(.caption2, size: 11, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(width: 116, alignment: .leading)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.07))
                            Capsule()
                                .fill(Theme.scale(for: floor.accuracy))
                                .frame(width: max(3, proxy.size.width * floor.accuracy))
                        }
                    }
                    .frame(height: 8)

                    Text("\(Int(floor.accuracy * 100))%")
                        .font(.mono(12, weight: .bold))
                        .foregroundStyle(Theme.scale(for: floor.accuracy))
                        .frame(width: 38, alignment: .trailing)

                    StarRating(stars: floor.stars, size: 9)
                        .frame(width: 46)
                }
                .frame(minHeight: 32)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Floor \(floor.levelID), \(floor.name)")
                .accessibilityValue(
                    "\(Int(floor.accuracy * 100)) percent correct, \(floor.stars) of 3 stars"
                )
            }
        }
    }
}

/// The confidence caveat, stated plainly rather than buried.
struct ReliabilityNoteView: View {
    let assessment: Assessment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: self.assessment.isReliable ? "checkmark.seal" : "info.circle")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(self.assessment.isReliable ? Theme.correct : Theme.hint)

            VStack(alignment: .leading, spacing: 6) {
                Text(self.assessment.isReliable ? "How much to trust this" : "Why the range is wide")
                    .font(.app(.subheadline, size: 13, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text(self.assessment.reliabilityNote)
                    .font(.app(.footnote, size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("""
                This is a game-based estimate from timed puzzles, not a clinical IQ test. It \
                measures reasoning under time pressure, which is a real ability but not the \
                only thing an IQ test measures.
                """)
                    .font(.app(.caption2, size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: Theme.Metrics.corner, style: .continuous)
                .fill(Theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Metrics.corner, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
    }
}