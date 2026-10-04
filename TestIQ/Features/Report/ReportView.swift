import SwiftUI

/// The assessment report.
///
/// Arranged as a reveal rather than a wall: score first, then profile, then the specific
/// advice. Sections fade in as they scroll into view so the screen does not arrive all at
/// once and get skimmed.
struct ReportView: View {
    @Environment(AppState.self) private var app
    @State private var radarSweep: Double = 0
    @State private var appearedSections: Set<String> = []

    private var assessment: Assessment { self.app.assessment ?? .empty }
    private var tips: [CoachingTip] { CoachingEngine.tips(for: self.assessment) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ConfettiView(isActive: self.app.progress.hasFinishedAscent)

            if self.assessment.totalItems == 0 {
                emptyState
            } else {
                content
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            self.app.recomputeAssessment()
            withAnimation(Motion.enabled ? .spring(response: 0.9, dampingFraction: 0.85) : nil) {
                self.radarSweep = 1
            }
        }
    }

    // MARK: - Content

    /// Section anchors, so a screen can be opened part-way down. Only reachable via the
    /// DEBUG launch argument below; production always opens at the top.
    private enum Section: String { case gauge, profile, strengths, coaching, breakdown }

    private var initialScrollTarget: Section? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-uiSection"),
              arguments.indices.contains(flag + 1),
              let section = Section(rawValue: arguments[flag + 1]) else { return nil }
        return section
        #else
        return nil
        #endif
    }

    private var content: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 26) {
                titleBlock

                ScoreGaugeView(
                    estimate: self.assessment.iqEstimate,
                    confidenceLow: self.assessment.confidenceLow,
                    confidenceHigh: self.assessment.confidenceHigh,
                    percentile: self.assessment.percentile,
                    band: self.assessment.band
                )
                .id(Section.gauge)
                .appearIn(0.1)

                ReliabilityNoteView(assessment: self.assessment)

                runSummary

                brainProfile
                    .id(Section.profile)

                strengthsSection
                    .id(Section.strengths)

                coachingSection
                    .id(Section.coaching)

                breakdownSection
                    .id(Section.breakdown)

                footer
            }
            .padding(Theme.Metrics.gutter)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            guard let section = self.initialScrollTarget else { return }
            proxy.scrollTo(section, anchor: .top)
        }
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("ASSESSMENT")
                .font(.app(.caption2, size: 11, weight: .heavy))
                .tracking(2.2)
                .foregroundStyle(Theme.accent)

            Text("IQ Ascent Report")
                .font(.app(.largeTitle, size: 30, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)

            Text("Recomputed from every floor you have played")
                .font(.app(.footnote, size: 13, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var runSummary: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text(self.assessment.headline)
                    .font(.app(.subheadline, size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().overlay(Theme.stroke)

                HStack(spacing: 0) {
                    StatTile(value: "\(self.assessment.totalItems)",
                             label: "Items answered")
                    Divider().frame(height: 34).overlay(Theme.stroke)
                    StatTile(value: "\(Int(self.assessment.overallAccuracy * 100))%",
                             label: "Accuracy", tint: Theme.correct)
                    Divider().frame(height: 34).overlay(Theme.stroke)
                    StatTile(value: "×\(min(5, max(1, self.assessment.bestStreak)))",
                             label: "Best streak", tint: Theme.incorrect)
                    Divider().frame(height: 34).overlay(Theme.stroke)
                    StatTile(value: "\(self.assessment.totalStars)",
                             label: "Stars", tint: Theme.hint)
                }
            }
        }
        .appearIn(0.05)
    }

    private var brainProfile: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(
                title: "Your brain profile",
                subtitle: "Eight axes, indexed 0–100 against the same scale as your headline score",
                symbol: "circle.hexagongrid.fill"
            )

            RadarChartView(scores: self.assessment.domainScores, sweep: self.radarSweep)
                .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                ForEach(self.assessment.domainScores) { score in
                    DomainRowView(score: score)
                }
            }
        }
        .appearIn(0.1)
    }

    private var strengthsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(
                title: "Where you're strongest",
                subtitle: self.assessment.strengths.isEmpty
                    ? "Not enough evidence yet"
                    : "These are the axes pulling your composite up",
                symbol: "arrow.up.right.circle.fill"
            )

            if self.assessment.strengths.isEmpty {
                Text("Clear more floors and your strongest areas will appear here.")
                    .font(.app(.footnote, size: 13, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                ForEach(self.assessment.strengths) { score in
                    StrengthCard(score: score)
                }
            }
        }
        .appearIn(0.12)
    }

    private var coachingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(
                title: "How to improve",
                subtitle: self.tips.isEmpty
                    ? "Nothing to flag yet"
                    : "Specific to what you actually got wrong",
                symbol: "lightbulb.fill"
            )

            if self.tips.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No weak spots flagged")
                            .font(.app(.headline, size: 15, weight: .bold))
                            .foregroundStyle(Theme.correct)
                        Text("""
                        Every axis is within reach of your composite across \(self.assessment.totalItems) \
                        answers, and no specific mistake repeated often enough to name. The most \
                        useful next step is simply more floors — the estimate tightens with every item.
                        """)
                        .font(.app(.footnote, size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                ForEach(self.tips) { tip in
                    CoachingCardView(tip: tip)
                }
            }
        }
        .appearIn(0.15)
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(
                title: "Floor by floor",
                subtitle: "Your best attempt at each level",
                symbol: "square.stack.3d.up.fill"
            )

            LevelBreakdownView(breakdown: self.assessment.levelBreakdown, starTotal: self.assessment.totalStars)
        }
        .appearIn(0.18)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if !self.app.progress.hasFinishedAscent {
                let next = self.app.progress.nextLevelID
                if let level = LevelCatalog.level(next) {
                    PrimaryButton(
                        title: "Play floor \(next): \(level.name)",
                        systemImage: "arrow.up",
                        tint: Theme.accent
                    ) {
                        self.app.open(next)
                    }
                }
            }

            QuietButton(title: "Back to the path", systemImage: "chevron.down") {
                self.app.goHome()
            }

            Text("Generated \(self.assessment.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.app(.caption2, size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.dots.scatter")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("No assessment yet")
                .font(.app(.title2, size: 22, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Play a floor and your profile will start building here.")
                .font(.app(.subheadline, size: 14, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Start floor 1", systemImage: "arrow.up") {
                self.app.open(1)
            }
            .padding(.horizontal, 40)
            QuietButton(title: "Back", systemImage: "chevron.down") { self.app.goHome() }
            Spacer()
        }
    }
}

/// A strength, framed as something to build on rather than just a high score.
private struct StrengthCard: View {
    let score: DomainScore

    var body: some View {
        GlassCard(padding: 15, tint: Theme.correct) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: self.score.domain.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.correct)
                    .frame(width: 32, height: 32)
                    .background { Circle().fill(Theme.correct.opacity(0.14)) }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(self.score.domain.title)
                            .font(.app(.headline, size: 15, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(Int(self.score.index))")
                            .font(.mono(16, weight: .heavy))
                            .foregroundStyle(Theme.correct)
                    }

                    Text(self.score.domain.blurb)
                        .font(.app(.footnote, size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("""
                    Indexed \(Int(self.score.index))/100 from \(self.score.itemCount) \
                    \(self.score.itemCount == 1 ? "item" : "items") at \
                    \(Int(self.score.accuracy * 100))% accuracy. This is the axis most worth \
                    protecting — the other seven are easier to move than this one is to keep.
                    """)
                    .font(.app(.caption2, size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}