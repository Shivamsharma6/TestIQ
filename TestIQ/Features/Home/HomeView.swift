import SwiftUI

/// The title screen and level map.
struct HomeView: View {
    @Environment(AppState.self) private var app
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var hasScrolled = false

    private var progress: PlayerProgress { app.progress }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 20) {
                header
                summaryStrip

                if app.progress.hasFinishedAscent || app.progress.levelsWithResults > 0 {
                    reportCard
                }

                LevelPathView(progress: self.progress) { levelID in
                    self.app.open(levelID)
                }
                .id(1)

                footer
            }
            .padding(.horizontal, Theme.Metrics.gutter)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .sheet(isPresented: $showAbout) { AboutSheet() }
        // The path climbs bottom to top, so a returning player would otherwise land on a
        // screen full of locked floors. Jump straight to where they actually are.
        .onAppear {
            guard !self.hasScrolled else { return }
            self.hasScrolled = true
            let target = self.app.progress.isUnlocked(self.app.progress.nextLevelID)
                ? self.app.progress.nextLevelID
                : self.app.progress.nextLevelID
            withAnimation(Motion.enabled ? Motion.gentle : nil) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("IQ ASCENT")
                        .font(.app(.largeTitle, size: 32, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Ten floors. One mind.")
                        .font(.app(.footnote, size: 13, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()

                HStack(spacing: 8) {
                    iconButton("gearshape", label: "Settings") { self.showSettings = true }
                    iconButton("info.circle", label: "About this test") { self.showAbout = true }
                }
            }

            if self.progress.clearedCount == 0, !self.progress.hasSeenIntro {
                GlassCard(tint: Theme.accent) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("How this works", systemImage: "sparkles")
                            .font(.app(.headline, size: 15, weight: .bold))
                            .foregroundStyle(Theme.accent)

                        Text("""
                        Each floor is one kind of thinking — patterns, numbers, words, logic, \
                        memory, space, abstraction. Difficulty climbs every floor, and floors 9 \
                        and 10 adapt to how you are actually doing.

                        At the top you get a full assessment: an estimated IQ with a confidence \
                        range, a breakdown of all eight abilities, and specific techniques for \
                        whatever you are weakest at.
                        """)
                        .font(.app(.subheadline, size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .appearIn(0.05)
            }
        }
        .padding(.top, 12)
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
                .background { Circle().fill(Theme.surface) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Summary

    private var summaryStrip: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 0) {
                StatTile(value: "\(self.progress.clearedCount)/\(LevelCatalog.count)",
                         label: "Floors cleared")
                Divider().frame(height: 34).overlay(Theme.stroke)
                StatTile(value: "\(self.progress.totalStars)/\(self.progress.maxStars)",
                         label: "Stars earned", tint: Theme.hint)
                Divider().frame(height: 34).overlay(Theme.stroke)
                StatTile(
                    value: self.progress.lastAssessment.map { String(Int($0.iqEstimate.rounded())) } ?? "—",
                    label: "Estimated IQ",
                    tint: Theme.accent
                )
            }
        }
    }

    private var reportCard: some View {
        Button {
            HapticsEngine.shared.tap()
            self.app.openReport()
        } label: {
            GlassCard(tint: Theme.accent) {
                HStack(spacing: 14) {
                    Image(systemName: "chart.dots.scatter")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 42, height: 42)
                        .background { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accent.opacity(0.14)) }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your assessment")
                            .font(.app(.headline, size: 16, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(self.progress.levelsWithResults) floors analysed · updated after every floor")
                            .font(.app(.caption, size: 12, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .buttonStyle(TileButtonStyle())
        .accessibilityLabel("Open your assessment report")
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text("Scores are estimates, not clinical measurements. Every report states its own confidence range.")
                .font(.app(.caption2, size: 11, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

extension PlayerProgress {
    /// How many floors have produced any recorded result, cleared or not.
    var levelsWithResults: Int { self.levelResults.count }
}

// MARK: - Settings

private struct SettingsSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Feedback") {
                    Toggle(isOn: Binding(
                        get: { app.progress.soundEnabled },
                        set: { app.setSound($0) }
                    )) {
                        Label("Sound effects", systemImage: "speaker.wave.2.fill")
                    }
                    Toggle(isOn: Binding(
                        get: { app.progress.hapticsEnabled },
                        set: { app.setHaptics($0) }
                    )) {
                        Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
                    }
                }

                Section {
                    LabeledContent("Floors cleared", value: "\(app.progress.clearedCount) of \(LevelCatalog.count)")
                    LabeledContent("Stars earned", value: "\(app.progress.totalStars) of \(app.progress.maxStars)")
                    LabeledContent("Floors analysed", value: "\(app.progress.levelsWithResults)")
                } header: {
                    Text("Progress")
                } footer: {
                    Text("Progress is stored on this device only. Nothing is uploaded.")
                }

                Section {
                    Button(role: .destructive) {
                        self.confirmReset = true
                    } label: {
                        Label("Reset all progress", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { self.dismiss() }
                }
            }
            .alert("Reset everything?", isPresented: $confirmReset) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    app.resetEverything()
                    self.dismiss()
                }
            } message: {
                Text("Every star, floor and report will be deleted. This cannot be undone.")
            }
        }
    }
}

// MARK: - About

private struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GlassCard(tint: Theme.accent) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("What the number means", systemImage: "function")
                                .font(.app(.headline, size: 16, weight: .bold))
                                .foregroundStyle(Theme.accent)
                            Text("""
                            Every puzzle carries a difficulty value on a shared scale, where 2.8 is \
                            defined as population average. Your answers build an estimate of your \
                            ability on that scale, which is then converted to the familiar \
                            mean-100, standard-deviation-15 scale people mean by "IQ".

                            The report always shows a confidence range alongside the estimate, and \
                            refuses to name a band when that range crosses a boundary. A short or \
                            inconsistent run produces a wide range on purpose — that is the honest \
                            answer, not a flaw.
                            """)
                            .font(.app(.subheadline, size: 14, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("How speed is scored", systemImage: "speedometer")
                                .font(.app(.headline, size: 16, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("""
                            Speed is a small bonus on top of a correct answer, and never a penalty \
                            of its own. Answering wrong fast scores exactly zero, so guessing is \
                            never a good trade. Deliberating past a certain point *is* penalised, \
                            simply by the time you no longer have left to answer with.
                            """)
                            .font(.app(.subheadline, size: 14, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Your puzzles are generated", systemImage: "wand.and.stars")
                                .font(.app(.headline, size: 16, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("""
                            Nothing is picked from a fixed question bank. Sequences, matrices, \
                            rotations and folded-paper items are all constructed to a difficulty \
                            you specify, which is why the ramp can be this precise and why no two \
                            runs are identical.
                            """)
                            .font(.app(.subheadline, size: 14, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(Theme.Metrics.gutter)
            }
            .background(Theme.background)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { self.dismiss() }
                }
            }
        }
    }
}