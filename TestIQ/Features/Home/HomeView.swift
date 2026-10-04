import SwiftUI

/// Play comes first; records, rewards, and the entire climb remain one scroll away.
struct HomeView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showSettings = false
    @State private var showAbout = false

    private var progress: PlayerProgress { self.app.progress }
    private var nextLevel: LevelDefinition {
        LevelCatalog.level(self.progress.nextLevelID) ?? LevelCatalog.all[0]
    }
    private var challengeLevel: LevelDefinition? {
        if self.progress.personalBestScore(for: self.nextLevel.id) != nil { return self.nextLevel }
        let latest = self.progress.attemptHistory.max { $0.completedAt < $1.completedAt }
            ?? self.progress.bestResults.max { $0.completedAt < $1.completedAt }
        return latest.flatMap { LevelCatalog.level($0.levelID) }
    }

    var body: some View {
        ZStack {
            ArcadeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    self.header
                    self.playCard
                    self.challengeCard
                    self.rewardsCard
                    self.progressButton
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(title: "The climb", subtitle: "Clear a floor. Unlock the next. Replay for glory.")
                        LevelPathView(progress: self.progress) { self.app.open($0) }
                    }
                    Text("A little practice. A new personal best.")
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(.horizontal, Theme.Metrics.gutter)
                .padding(.top, 14)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: self.$showSettings) { SettingsSheet() }
        .sheet(isPresented: self.$showAbout) { AboutSheet() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(Theme.lime)
                Text("ASCENT")
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Ascent")
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            self.iconButton("info", label: "About Ascent") { self.showAbout = true }
            self.iconButton("slider.horizontal.3", label: "Settings") { self.showSettings = true }
        }
    }

    private var playCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    ArcadeEyebrow(text: self.progress.hasFinishedAscent ? "Summit unlocked" : "Your next challenge")
                    Text(self.progress.hasFinishedAscent ? "Top that." : "Onward.\nUpward.")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if !self.dynamicTypeSize.isAccessibilitySize {
                    ArcadeFloorEmblem(symbol: "arrow.up.forward", size: 78)
                        .padding(.top, 8)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("FLOOR \(self.nextLevel.id)  /  \(LevelCatalog.count)")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.lime)
                Text(self.nextLevel.name)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(self.nextLevel.itemCount) puzzles · \(self.nextLevel.isAdaptive ? "Mixed skills" : self.nextLevel.domain.shortTitle)")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .accessibilityElement(children: .combine)

            PrimaryButton(
                title: self.progress.hasFinishedAscent ? "Play the summit" : "Play floor \(self.nextLevel.id)",
                systemImage: "play.fill", tint: Theme.lime
            ) {
                self.app.open(self.nextLevel.id)
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerLarge, style: .continuous)
                .fill(LinearGradient(colors: [Theme.surfaceRaised, Theme.surface], startPoint: .topTrailing, endPoint: .bottomLeading))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerLarge, style: .continuous)
                        .strokeBorder(Theme.lime.opacity(0.26), lineWidth: 1)
                }
        }
    }

    private var challengeCard: some View {
        GlassCard(padding: 18, tint: Theme.violet) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                    Text("YOU VS. YOUR BEST")
                        .tracking(1.1)
                }
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.violet)

                if let level = self.challengeLevel,
                   let score = self.progress.personalBestScore(for: level.id) {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(score.formatted()) pts")
                                .font(.system(.title2, design: .rounded, weight: .heavy).monospacedDigit())
                                .foregroundStyle(Theme.textPrimary)
                            Text("Floor \(level.id) · \(level.name)")
                                .font(.system(.footnote, design: .rounded, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Button {
                            HapticsEngine.shared.tap()
                            self.app.open(level.id)
                        } label: {
                            Image(systemName: "arrow.up.right")
                                .font(.system(.headline, weight: .bold))
                                .foregroundStyle(Theme.violet)
                                .frame(width: 48, height: 48)
                                .background(Theme.violet.opacity(0.13), in: RoundedRectangle(cornerRadius: 15))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Challenge your personal best on floor \(level.id), \(level.name)")
                        .accessibilityHint("Your record is \(score) points")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Fresh start. Empty scoreboard.")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Finish your first floor. Give yourself a score to chase.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }

    private var rewardsCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                ArcadeEyebrow(text: "The trophy shelf", tint: Theme.textTertiary)
                Spacer()
                Label("\(self.progress.totalStars)/\(self.progress.maxStars)", systemImage: "star.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.hint)
                    .accessibilityLabel("\(self.progress.totalStars) of \(self.progress.maxStars) stars earned")
            }
            HStack(spacing: 6) {
                ForEach(LevelCatalog.all) { level in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(self.progress.isCleared(level.id) ? Theme.lime : Theme.surfaceRaised)
                        .frame(height: 8)
                }
            }
            .accessibilityHidden(true)
            HStack {
                Text("\(self.progress.clearedCount) of \(LevelCatalog.count) floors cleared")
                Spacer()
                Text("\(self.progress.completedRunCount) rounds")
            }
            .font(.system(.caption, design: .rounded, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private var progressButton: some View {
        Button {
            HapticsEngine.shared.tap()
            self.app.openReport()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(Theme.violet)
                    .frame(width: 42, height: 42)
                    .background(Theme.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your progress")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Real rounds. Personal records. Better practice.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .multilineTextAlignment(.leading)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Metrics.corner))
        }
        .buttonStyle(TileButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Open your practice progress and personal records")
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.shared.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: Theme.Metrics.minTarget, height: Theme.Metrics.minTarget)
                .background(Theme.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

extension PlayerProgress {
    var levelsWithResults: Int { self.levelResults.count }
}

private struct SettingsSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Feedback") {
                    Toggle(isOn: Binding(get: { self.app.progress.soundEnabled }, set: { self.app.setSound($0) })) {
                        Label("Sound effects", systemImage: "speaker.wave.2.fill")
                    }
                    Toggle(isOn: Binding(get: { self.app.progress.hapticsEnabled }, set: { self.app.setHaptics($0) })) {
                        Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    Text("Animations follow your device’s Reduce Motion setting.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    LabeledContent("Floors cleared", value: "\(self.app.progress.clearedCount) of \(LevelCatalog.count)")
                    LabeledContent("Stars earned", value: "\(self.app.progress.totalStars) of \(self.app.progress.maxStars)")
                    LabeledContent("Completed rounds", value: "\(self.app.progress.completedRunCount)")
                } header: {
                    Text("Progress")
                } footer: {
                    Text("Progress is stored on this device only. Nothing is uploaded.")
                }
                Section {
                    Button(role: .destructive) { self.confirmReset = true } label: {
                        Label("Reset all progress", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .tint(Theme.violet)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { self.dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .alert("Reset everything?", isPresented: self.$confirmReset) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    self.app.resetEverything()
                    self.dismiss()
                }
            } message: {
                Text("Every star, personal record, and saved round will be deleted. This cannot be undone.")
            }
        }
    }
}

private struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    self.aboutCard("A game for your grey matter", symbol: "brain.head.profile", text:
                        "Climb ten floors of patterns, numbers, words, logic, memory, and spatial puzzles. Learn a technique, keep a combo alive, and give your personal best some competition.")
                    self.aboutCard("Points with a purpose", symbol: "bolt.fill", text:
                        "Correct answers earn points. Quicker correct answers and consecutive hits earn more; hints reduce your score. Stars reward accuracy, with pace needed for the third star. Replays keep your earned rewards safe.")
                    self.aboutCard("Practice, in perspective", symbol: "chart.xyaxis.line", text:
                        "Your progress describes performance in this game. These puzzles are not a validated IQ test, and a game score cannot measure your intelligence. Practice trends compare recorded rounds only when enough similar puzzles are available.")
                    self.aboutCard("Your next attempt", symbol: "arrow.clockwise", text:
                        "Replays generate new puzzle sets, though some patterns may recur. The final two floors can use your previous results to choose a starting difficulty. A round’s puzzle set is fixed before play begins.")
                }
                .padding(Theme.Metrics.gutter)
            }
            .background(Theme.background)
            .navigationTitle("About Ascent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { self.dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .tint(Theme.lime)
    }

    private func aboutCard(_ title: String, symbol: String, text: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: symbol)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.lime)
                Text(text)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
