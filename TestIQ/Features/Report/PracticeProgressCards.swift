import SwiftUI

/// Each bar is an actual recorded round. It is descriptive history, not a trend
/// claim; adaptive difficulty and puzzle mix may differ from one round to another.
struct PracticeHistoryCard: View {
    let levelID: Int
    let rounds: [LevelResult]
    let personalBest: Int?
    @State private var showDetails = false

    private var visibleRounds: [LevelResult] { Array(self.rounds.suffix(8)) }

    var body: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(LevelCatalog.level(self.levelID)?.name ?? "Floor \(self.levelID)")
                        .font(.app(.title3, size: 20, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                    Text("RECENT ROUNDS · ACCURACY")
                        .font(.app(.caption2, size: 10, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(Theme.textTertiary)
                }

                if let latest = self.rounds.last {
                    HStack(alignment: .top, spacing: 16) {
                        StatTile(value: "\(latest.score)", label: "Latest points", tint: Theme.accent)
                        if let personalBest = self.personalBest {
                            StatTile(value: "\(personalBest)", label: "Personal best")
                        }
                    }
                    self.chart
                    Text("Oldest → newest · Recorded rounds \(self.rounds.count - self.visibleRounds.count + 1)–\(self.rounds.count)")
                        .font(.app(.caption2, size: 11, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                    Text("Each bar shows one round. Puzzles can vary; use the comparison below to check changes on similar challenges.")
                        .font(.app(.footnote, size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    DisclosureGroup(isExpanded: self.$showDetails) {
                        VStack(spacing: 13) {
                            ForEach(self.visibleRounds) { round in
                                self.detailRow(round)
                            }
                        }
                        .padding(.top, 12)
                    } label: {
                        Text("Round details")
                            .font(.app(.subheadline, size: 13, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(minHeight: Theme.Metrics.minTarget)
                    }
                    .tint(Theme.accent)
                } else {
                    Text("No rounds recorded here yet. Your saved personal best is still part of your records below.")
                        .font(.app(.subheadline, size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var chart: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(self.visibleRounds.enumerated()), id: \.element.id) { index, round in
                VStack(spacing: 8) {
                    Text("\(Int((round.accuracy * 100).rounded()))%")
                        .font(.mono(10, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 6).fill(Theme.surfaceRaised)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(round.id == self.rounds.last?.id ? Theme.accent : Theme.accent.opacity(0.42))
                            .frame(height: max(3, 96 * max(0, min(1, round.accuracy))))
                    }
                    .frame(height: 96)
                    Text("\(self.rounds.count - self.visibleRounds.count + index + 1)")
                        .font(.mono(10, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Recorded round \(self.rounds.count - self.visibleRounds.count + index + 1)")
                .accessibilityValue("\(Int((round.accuracy * 100).rounded())) percent correct, \(round.score) points, \(round.completedAt.formatted(date: .abbreviated, time: .shortened))")
            }
        }
        .accessibilityLabel("Accuracy for the last \(self.visibleRounds.count) recorded rounds on floor \(self.levelID)")
    }

    private func detailRow(_ round: LevelResult) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(round.completedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.app(.caption, size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(round.correctCount)/\(round.items.count) correct · \(round.items.reduce(0) { $0 + $1.hintsUsed }) hints")
                    .font(.app(.caption2, size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 4)
            Text("\(round.score) pts")
                .font(.mono(13, weight: .bold))
                .foregroundStyle(round.id == self.rounds.last?.id ? Theme.accent : Theme.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Only presents comparisons already vetted by ProgressInsights. The visible sample
/// counts distinguish matched evidence from all completed rounds on a floor.
struct PracticeTrendCard: View {
    let trend: PracticeTrend

    var body: some View {
        GlassCard(padding: 16, tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: self.trend.accuracyChange > 0 ? "arrow.up.right" : "scope")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Earlier → recent")
                            .font(.app(.headline, size: 18, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(self.accuracyHeadline)
                            .font(.app(.subheadline, size: 13, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 13) {
                    GridRow {
                        Text("SIMILAR PUZZLES")
                        Text("EARLIER")
                        Text("RECENT")
                    }
                    .font(.app(.caption2, size: 9, weight: .heavy))
                    .foregroundStyle(Theme.textTertiary)
                    self.metricRow(
                        "Accuracy",
                        earlier: self.percent(self.trend.earlier.accuracy),
                        recent: self.percent(self.trend.recent.accuracy)
                    )
                    self.metricRow(
                        "Hints / puzzle",
                        earlier: self.number(self.trend.earlier.hintsPerItem),
                        recent: self.number(self.trend.recent.hintsPerItem)
                    )
                    self.metricRow(
                        "Correct-answer pace",
                        earlier: self.seconds(self.trend.earlier.medianCorrectSeconds),
                        recent: self.seconds(self.trend.recent.medianCorrectSeconds)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 7) {
                    Text(self.paceNote)
                        .font(.app(.footnote, size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(self.trend.roundsCompared) rounds compared · \(self.trend.earlier.itemCount) earlier and \(self.trend.recent.itemCount) recent matching puzzles.")
                        .font(.app(.caption2, size: 11, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                    Text("Matched by puzzle type, difficulty and time allowance. Pace summarizes correct answers within those groups. Small samples can vary.")
                        .font(.app(.caption2, size: 11, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func metricRow(_ label: String, earlier: String, recent: String) -> some View {
        GridRow {
            Text(label)
                .font(.app(.footnote, size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(earlier)
                .font(.mono(14, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
            Text(recent)
                .font(.mono(14, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): earlier \(earlier), recent \(recent)")
    }

    private var accuracyHeadline: String {
        let difference = self.trend.accuracyChange * 100
        if abs(difference) < 0.05 { return "Accuracy held steady in these samples" }
        let direction = difference > 0 ? "up" : "down"
        return "Accuracy \(direction) \(self.number(abs(difference))) percentage points"
    }

    private var paceNote: String {
        if self.trend.isFasterWithoutAccuracyLoss {
            return "Faster correct answers, with accuracy holding or improving. Keep that balance."
        }
        guard let earlier = self.trend.earlier.medianCorrectSeconds,
              let recent = self.trend.recent.medianCorrectSeconds else {
            return "More correct answers are needed to compare pace. Accuracy comes first."
        }
        if recent < earlier && self.trend.accuracyChange < 0 {
            return "Answers were quicker, but accuracy dipped. Focus on the rule before pushing the pace."
        }
        return "Keep accuracy first. Pace can develop as the puzzle techniques become familiar."
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func percent(_ value: Double) -> String { "\(self.number(value * 100))%" }
    private func seconds(_ value: Double?) -> String {
        value.map { "\(self.number($0))s" } ?? "—"
    }
}
