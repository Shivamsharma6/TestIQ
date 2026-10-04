import Foundation
import SwiftUI

/// Root application state: profile, routing, and the stored assessment.
///
/// Deliberately thin. All game rules live in `Core`, which means this type's only jobs are
/// to hold the profile, decide what is on screen, and hand a finished run to the scoring
/// engine.
@MainActor
@Observable
final class AppState {
    var progress: PlayerProgress
    var route: Route = .home
    var assessment: Assessment?
    /// The round just played, distinct from the profile's lifetime records.
    private(set) var lastResult: LevelResult?
    private(set) var previousBestScore: Int?
    var saveWarning: String?
    /// Bumped whenever progress changes so views that read it refresh.
    private(set) var revision = 0

    enum Route: Hashable {
        case home
        case levelIntro(Int)
        case game(levelID: Int, attempt: Int)
        case levelComplete(Int)
        case report
    }

    private let store: ProgressStore

    init(store: ProgressStore? = nil) {
        let resolved = store ?? ProgressStore.shared
        self.store = resolved
        self.progress = resolved.load()
        self.assessment = self.progress.lastAssessment
        self.saveWarning = resolved.lastError
        #if DEBUG
        self.applyDebugLaunchRoute()
        #endif
    }

    #if DEBUG
    /// Debug-only deep link, used to verify a screen without playing through to it:
    /// `xcrun simctl launch <device> moon.TestIQ -uiRoute report`.
    ///
    /// Guarded by `#if DEBUG` so it cannot exist in a release build. It is a deliberate
    /// affordance rather than test-only scaffolding: screenshotting and eyeballing the
    /// report is the only practical way to catch a layout that a unit test cannot.
    private func applyDebugLaunchRoute() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-uiRoute"),
              arguments.indices.contains(flag + 1) else { return }
        let value = arguments[flag + 1]

        switch value {
        case "report":
            self.recomputeAssessment()
            self.route = .report
        case "game":
            let levelID = self.debugLevelID(arguments)
            guard LevelCatalog.level(levelID) != nil else { return }
            self.progress.unlockedLevelID = max(self.progress.unlockedLevelID, levelID)
            self.route = .game(levelID: levelID, attempt: 0)
        case "intro":
            let levelID = self.debugLevelID(arguments)
            guard LevelCatalog.level(levelID) != nil else { return }
            self.route = .levelIntro(levelID)
        case "results":
            let levelID = self.debugLevelID(arguments)
            guard let latest = self.progress.latestResult(for: levelID) else { return }
            self.lastResult = latest
            self.previousBestScore = self.progress.attemptHistory
                .filter { $0.levelID == levelID && $0.id != latest.id }.map(\.score).max()
            self.route = .levelComplete(levelID)
        default:
            break
        }
    }

    private func debugLevelID(_ arguments: [String]) -> Int {
        guard let index = arguments.firstIndex(of: "-uiLevel"),
              arguments.indices.contains(index + 1) else { return 1 }
        return Int(arguments[index + 1]) ?? 1
    }
    #endif

    // MARK: - Routing

    func open(_ levelID: Int) {
        guard self.progress.isUnlocked(levelID) else { return }
        self.route = .levelIntro(levelID)
    }

    func start(_ levelID: Int) {
        guard self.progress.isUnlocked(levelID) else { return }
        let attempt = self.progress.attempts(for: levelID) + 1
        self.lastResult = nil
        self.previousBestScore = nil
        self.route = .game(levelID: levelID, attempt: attempt)
    }

    func finish(_ result: LevelResult) {
        guard self.lastResult?.id != result.id else { return }
        self.previousBestScore = self.progress.personalBestScore(for: result.levelID)
        self.store.record(result)
        self.progress = self.store.load()
        self.saveWarning = self.store.lastError
        self.lastResult = self.progress.latestResult(for: result.levelID)
        self.saveWarning = self.store.lastError
        self.recomputeAssessment()
        self.revision += 1
        self.route = .levelComplete(result.levelID)
    }

    func goHome() {
        self.route = .home
    }

    func openReport() {
        self.recomputeAssessment()
        self.route = .report
    }

    /// Coaching reflects the most recent result per floor, with legacy bests as fallback.
    func recomputeAssessment() {
        guard !self.progress.levelResults.isEmpty else {
            self.assessment = .empty
            return
        }
        let fresh = ScoringEngine.assess(self.progress.recentSummary)
        self.assessment = fresh
        var updated = self.progress
        updated.lastAssessment = fresh
        self.store.save(updated)
        self.progress = self.store.load()
        self.saveWarning = self.store.lastError
        self.revision += 1
    }

    func commit(assessment: Assessment) {
        self.assessment = assessment
        var updated = self.progress
        updated.lastAssessment = assessment
        self.store.save(updated)
        self.progress = self.store.load()
        self.saveWarning = self.store.lastError
        self.revision += 1
    }

    // MARK: - Settings

    func setSound(_ enabled: Bool) {
        var updated = self.progress
        updated.soundEnabled = enabled
        SoundEngine.shared.isEnabled = enabled
        self.store.save(updated)
        self.progress = self.store.load()
        self.saveWarning = self.store.lastError
    }

    func setHaptics(_ enabled: Bool) {
        var updated = self.progress
        updated.hapticsEnabled = enabled
        HapticsEngine.shared.isEnabled = enabled
        self.store.save(updated)
        self.progress = self.store.load()
        self.saveWarning = self.store.lastError
    }

    func markIntroSeen() {
        guard !self.progress.hasSeenIntro else { return }
        var updated = self.progress
        updated.hasSeenIntro = true
        self.store.save(updated)
        self.progress = self.store.load()
        self.saveWarning = self.store.lastError
    }

    func markInteractionLearned(_ key: String) {
        guard !self.progress.learnedInteractions.contains(key) else { return }
        var updated = self.progress
        updated.learnedInteractions.insert(key)
        updated.hasSeenIntro = true
        self.store.save(updated)
        self.progress = self.store.load()
        self.saveWarning = self.store.lastError
    }

    func resetEverything() {
        self.store.reset()
        self.progress = self.store.load()
        self.saveWarning = self.store.lastError
        SoundEngine.shared.isEnabled = self.progress.soundEnabled
        HapticsEngine.shared.isEnabled = self.progress.hapticsEnabled
        self.assessment = nil
        self.lastResult = nil
        self.previousBestScore = nil
        self.saveWarning = self.store.lastError
        self.revision += 1
        self.route = .home
    }

    // MARK: - Adaptive difficulty

    /// A player's demonstrated ability on the latent scale, used by the adaptive floors.
    /// Returns `nil` until enough evidence exists to be worth bending the ramp for.
    func currentAbility() -> Double? {
        guard let assessment = self.progress.lastAssessment ?? self.assessment else { return nil }
        guard assessment.totalItems >= 12 else { return nil }
        return assessment.compositeTheta
    }
}
