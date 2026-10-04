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
        self.applyDebugLaunchRoute()
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
            let levelID = arguments.contains("-uiLevel")
                ? Int(arguments[(arguments.firstIndex(of: "-uiLevel") ?? 0) + 1]) ?? 1
                : 1
            self.progress.unlockedLevelID = max(self.progress.unlockedLevelID, levelID)
            self.route = .game(levelID: levelID, attempt: 0)
        case "intro":
            let levelID = Int(value.split(separator: ":").last.map(String.init) ?? "") ?? 1
            self.route = .levelIntro(levelID)
        default:
            break
        }
    }
    #endif

    // MARK: - Routing

    func open(_ levelID: Int) {
        guard self.progress.isUnlocked(levelID) else { return }
        self.route = .levelIntro(levelID)
    }

    func start(_ levelID: Int) {
        let attempt = self.progress.attempts(for: levelID)
        self.route = .game(levelID: levelID, attempt: attempt)
    }

    func finish(_ result: LevelResult) {
        self.store.record(result)
        self.progress = self.store.load()
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

    /// Recomputes the report from every stored attempt. Called whenever the report opens
    /// so it always reflects the player's current best results rather than a snapshot
    /// taken at the moment they first reached the summit.
    func recomputeAssessment() {
        guard !self.progress.levelResults.isEmpty else {
            self.assessment = .empty
            return
        }
        let fresh = ScoringEngine.assess(self.progress.summary)
        self.assessment = fresh
        var updated = self.progress
        updated.lastAssessment = fresh
        self.store.save(updated)
        self.progress = self.store.load()
        self.revision += 1
    }

    func commit(assessment: Assessment) {
        self.assessment = assessment
        var updated = self.progress
        updated.lastAssessment = assessment
        self.store.save(updated)
        self.progress = self.store.load()
        self.revision += 1
    }

    // MARK: - Settings

    func setSound(_ enabled: Bool) {
        var updated = self.progress
        updated.soundEnabled = enabled
        SoundEngine.shared.isEnabled = enabled
        self.store.save(updated)
        self.progress = self.store.load()
    }

    func setHaptics(_ enabled: Bool) {
        var updated = self.progress
        updated.hapticsEnabled = enabled
        self.store.save(updated)
        self.progress = self.store.load()
    }

    func markIntroSeen() {
        guard !self.progress.hasSeenIntro else { return }
        var updated = self.progress
        updated.hasSeenIntro = true
        self.store.save(updated)
        self.progress = self.store.load()
    }

    func resetEverything() {
        self.store.reset()
        self.progress = self.store.load()
        self.assessment = nil
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