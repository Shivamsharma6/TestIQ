import SwiftUI

/// Practice history and personal records are deliberately separate: a replay is useful
/// evidence even when it does not beat an earlier score.
struct ReportView: View {
    @Environment(AppState.self) private var app
    @State private var selectedLevelID: Int?

    private var assessment: Assessment { self.app.assessment ?? .empty }
    private var tips: [CoachingTip] { CoachingEngine.tips(for: self.assessment) }
    private var history: [LevelResult] {
        self.app.progress.attemptHistory.sorted { $0.completedAt < $1.completedAt }
    }
    private var playedLevels: [LevelDefinition] {
        let recorded = Set(self.history.map(\.levelID))
        return LevelCatalog.all.filter {
            recorded.contains($0.id) || self.app.progress.levelResults[$0.id] != nil
        }
    }
    private var focusedLevelID: Int {
        self.selectedLevelID ?? self.history.last?.levelID ?? self.playedLevels.first?.id ?? 1
    }
    private var focusedRounds: [LevelResult] {
        self.history.filter { $0.levelID == self.focusedLevelID }
    }
    private var focusedTrend: PracticeTrend? {
        ProgressInsights.trends(in: self.history).first { $0.levelID == self.focusedLevelID }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if self.playedLevels.isEmpty {
                self.emptyState
            } else {
                self.content
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { self.app.recomputeAssessment() }
    }

    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    self.header
                    self.overview.id("gauge")
                    self.practiceSection.id("profile")
                    self.coachingSection.id("coaching")
                    self.recordsSection.id("breakdown")
                    self.footer
                }
                .padding(Theme.Metrics.gutter)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                #if DEBUG
                let arguments = ProcessInfo.processInfo.arguments
                if let flag = arguments.firstIndex(of: "-uiSection"),
                   arguments.indices.contains(flag + 1) {
                    proxy.scrollTo(arguments[flag + 1], anchor: .top)
                }
                #endif
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                self.app.goHome()
            } label: {
                Label("The ascent", systemImage: "arrow.left")
                    .font(.app(.subheadline, size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minHeight: Theme.Metrics.minTarget)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Returns to your floor map")

            VStack(alignment: .leading, spacing: 5) {
                Text("YOU VS. YOUR PERSONAL BEST")
                    .font(.app(.caption2, size: 10, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(Theme.accent)
                Text("Your progress")
                    .font(.app(.largeTitle, size: 34, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text("Every round gives you something to build on.")
                    .font(.app(.subheadline, size: 14, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
    }

    private var overview: some View {
        GlassCard(padding: 18, tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 12) {
                    StatTile(value: "\(self.history.count)", label: "Recorded rounds", tint: Theme.accent)
                    StatTile(value: "\(self.app.progress.totalStars)", label: "Stars earned", tint: Theme.hint)
                    StatTile(value: "\(self.app.progress.clearedCount)/\(LevelCatalog.count)", label: "Floors cleared")
                }

                if let latest = self.history.last {
                    Divider().overlay(Theme.stroke)
                    VStack(alignment: .leading, spacing: 10) {
                        Label("LATEST ROUND · FLOOR \(latest.levelID)", systemImage: "flag.checkered")
                            .font(.app(.caption2, size: 10, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(Theme.accent)
                        Text(LevelCatalog.level(latest.levelID)?.name ?? "Floor \(latest.levelID)")
                            .font(.app(.title2, size: 24, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(latest.score)")
                                .font(.mono(44, weight: .heavy))
                                .foregroundStyle(Theme.textPrimary)
                            Text("POINTS")
                                .font(.app(.caption2, size: 11, weight: .heavy))
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            StarRating(stars: latest.stars, size: 15)
                        }
                        Text("\(latest.correctCount) of \(latest.items.count) correct · \(Int((latest.accuracy * 100).rounded()))% accuracy")
                            .font(.app(.subheadline, size: 14, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        if let best = self.app.progress.personalBestScore(for: latest.levelID) {
                            Text("Floor \(latest.levelID) personal best: \(best) points")
                                .font(.app(.footnote, size: 12, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                } else {
                    Text("Your saved records are safe. Play a new round to start your practice timeline.")
                        .font(.app(.subheadline, size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeading(title: "Find your next edge", subtitle: "Explore your practice, one floor at a time.", symbol: "chart.bar.xaxis")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(self.playedLevels) { level in
                        Button {
                            self.selectedLevelID = level.id
                            HapticsEngine.shared.tap()
                        } label: {
                            Text("Floor \(level.id)")
                                .font(.app(.subheadline, size: 13, weight: .bold))
                                .padding(.horizontal, 16)
                                .frame(minHeight: Theme.Metrics.minTarget)
                                .foregroundStyle(self.focusedLevelID == level.id ? Theme.background : Theme.textSecondary)
                                .background {
                                    Capsule().fill(self.focusedLevelID == level.id ? Theme.accent : Theme.surface)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Floor \(level.id), \(level.name)")
                        .accessibilityAddTraits(self.focusedLevelID == level.id ? [.isSelected] : [])
                    }
                }
            }
            .scrollIndicators(.hidden)

            PracticeHistoryCard(
                levelID: self.focusedLevelID,
                rounds: self.focusedRounds,
                personalBest: self.app.progress.personalBestScore(for: self.focusedLevelID)
            )

            if let trend = self.focusedTrend {
                PracticeTrendCard(trend: trend)
            } else {
                self.buildComparisonCard
            }

            if self.app.progress.isUnlocked(self.focusedLevelID) {
                QuietButton(title: "Play floor \(self.focusedLevelID) again", systemImage: "arrow.clockwise") {
                    self.app.open(self.focusedLevelID)
                }
            }
        }
    }

    private var buildComparisonCard: some View {
        GlassCard(padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Build your comparison")
                        .font(.app(.headline, size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(self.comparisonPrompt)
                        .font(.app(.footnote, size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var comparisonPrompt: String {
        let needed = max(0, 4 - self.focusedRounds.count)
        if needed > 0 {
            return "Record \(needed) more \(needed == 1 ? "round" : "rounds") here to begin comparing earlier and recent practice. We also need enough similar puzzles in both groups."
        }
        return "Keep practicing this floor. There aren’t enough similar puzzles in the earlier and recent groups yet for a fair comparison."
    }

    private var coachingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(
                title: "Your next move",
                subtitle: self.history.isEmpty
                    ? "Techniques based on your saved floor records."
                    : "Techniques based on your latest recorded practice on each floor.",
                symbol: "bolt.fill"
            )
            if self.tips.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Keep your rhythm")
                            .font(.app(.headline, size: 16, weight: .bold))
                            .foregroundStyle(Theme.accent)
                        Text("Choose a floor, check each rule before answering, and aim for a round with fewer hints. Specific techniques will appear when your answers reveal a pattern to practice.")
                            .font(.app(.footnote, size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                ForEach(self.tips) { tip in CoachingCardView(tip: tip) }
            }
        }
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Personal bests", subtitle: "Your highest points and earned stars stay yours.", symbol: "trophy.fill")
            GlassCard(padding: 16) {
                VStack(spacing: 16) {
                    ForEach(self.playedLevels) { level in
                        HStack(spacing: 12) {
                            Text(String(format: "%02d", level.id))
                                .font(.mono(16, weight: .heavy))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(level.name)
                                    .font(.app(.subheadline, size: 14, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)
                                StarRating(stars: self.app.progress.stars(for: level.id), size: 11)
                            }
                            Spacer(minLength: 8)
                            if let best = self.app.progress.personalBestScore(for: level.id) {
                                Text("\(best) pts")
                                    .font(.mono(16, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            PrimaryButton(
                title: self.app.progress.hasFinishedAscent ? "Choose your next challenge" : "Continue the ascent",
                systemImage: "play.fill"
            ) {
                if self.app.progress.hasFinishedAscent {
                    self.app.goHome()
                } else {
                    self.app.open(self.app.progress.nextLevelID)
                }
            }
            Text("These are your results in TestIQ puzzles. Practice gains here do not measure or guarantee a change in IQ.")
                .font(.app(.caption, size: 12, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                self.header
                GlassCard(padding: 24, tint: Theme.accent) {
                    VStack(alignment: .leading, spacing: 18) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(Theme.accent)
                        Text("Your first round starts the story.")
                            .font(.app(.title, size: 30, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Play a floor to set a personal best. Return for your recent rounds, useful techniques, and fair comparisons as your practice builds.")
                            .font(.app(.subheadline, size: 15, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        PrimaryButton(title: "Play floor 1", systemImage: "play.fill") {
                            self.app.open(1)
                        }
                    }
                }
            }
            .padding(Theme.Metrics.gutter)
        }
    }
}
