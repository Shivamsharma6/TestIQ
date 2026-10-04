import XCTest
@testable import IQCore

final class ProgressTests: XCTestCase {
    func testLegacySavePreservesRewardsAndSettingsWithoutInventingHistory() throws {
        let oldBest = round("legacy", correct: 5, stars: 3, score: 900)
        let data = try JSONSerialization.data(withJSONObject: [
            "unlockedLevelID": 4,
            "levelResults": ["1": try JSONSerialization.jsonObject(with: encoder.encode(oldBest))],
            "soundEnabled": false, "hapticsEnabled": false, "hasSeenIntro": true
        ])
        let progress = try decoder.decode(PlayerProgress.self, from: data)
        XCTAssertEqual(progress.unlockedLevelID, 4)
        XCTAssertEqual(progress.stars(for: 1), 3)
        XCTAssertEqual(progress.personalBestScore(for: 1), 900)
        XCTAssertFalse(progress.soundEnabled)
        XCTAssertFalse(progress.hapticsEnabled)
        XCTAssertTrue(progress.hasSeenIntro)
        XCTAssertTrue(progress.attemptHistory.isEmpty)
        XCTAssertTrue(progress.learnedInteractions.isEmpty)
    }

    func testWeakerReplayIsLatestWithoutReplacingPersonalBest() {
        var progress = PlayerProgress()
        progress.record(round("first", correct: 5, stars: 3, score: 900))
        progress.record(round("second", correct: 1, stars: 0, score: 80))
        XCTAssertEqual(progress.attemptHistory.map(\.id), ["first", "second"])
        XCTAssertEqual(progress.latestResult(for: 1)?.score, 80)
        XCTAssertEqual(progress.personalBestScore(for: 1), 900)
        XCTAssertEqual(progress.levelResults[1]?.id, "first")
        XCTAssertEqual(progress.stars(for: 1), 3)
        XCTAssertEqual(progress.unlockedLevelID, 2)
        XCTAssertEqual(progress.attempts(for: 1), 2)
        XCTAssertEqual(progress.attemptHistory.last?.attempts, 2)
    }

    func testDuplicateCompletionDoesNotCountTwice() {
        var progress = PlayerProgress()
        let result = round("same", correct: 4, stars: 2, score: 400)
        progress.record(result)
        progress.record(result)
        XCTAssertEqual(progress.completedRunCount, 1)
        XCTAssertEqual(progress.attempts(for: 1), 1)
    }

    func testEarnedStarsDoNotDropWhenAccuracyImprovesButPaceSlows() {
        var progress = PlayerProgress()
        progress.record(round("fast", correct: 5, stars: 3, score: 500))
        progress.record(round("slow", correct: 6, stars: 2, score: 600))
        XCTAssertEqual(progress.levelResults[1]?.id, "slow")
        XCTAssertEqual(progress.stars(for: 1), 3)
        XCTAssertEqual(progress.totalStars, 3)
    }

    func testArcadeRecordIsHighestPointsEvenWhenAccuracyRecordDiffers() {
        var progress = PlayerProgress()
        progress.record(round("points", correct: 5, stars: 2, score: 700))
        progress.record(round("accuracy", correct: 6, stars: 2, score: 600))
        XCTAssertEqual(progress.levelResults[1]?.id, "accuracy")
        XCTAssertEqual(progress.personalBestScore(for: 1), 700)
    }

    func testLegacyHighScoreSurvivesMoreAccurateLowerScoringReplay() throws {
        var progress = PlayerProgress()
        progress.levelResults[1] = round("legacy", correct: 5, stars: 3, score: 900)
        progress.record(round("new-accuracy", correct: 6, stars: 2, score: 600))
        XCTAssertEqual(progress.personalBestScore(for: 1), 900)
        XCTAssertEqual(progress.levelResults[1]?.id, "new-accuracy")
        XCTAssertEqual(progress.attemptHistory.count, 1)
        let reloaded = try decoder.decode(PlayerProgress.self, from: encoder.encode(progress))
        XCTAssertEqual(reloaded.personalBestScore(for: 1), 900)
        XCTAssertEqual(reloaded.stars(for: 1), 3)
    }

    func testNewSaveRoundTripsHistoryAndLearnedInteractions() throws {
        var progress = PlayerProgress()
        progress.record(round("one", correct: 4, stars: 2, score: 400))
        progress.learnedInteractions.insert("choice")
        let decoded = try decoder.decode(PlayerProgress.self, from: encoder.encode(progress))
        XCTAssertEqual(decoded, progress)
    }

    func testCoachingSummaryUsesLatestAttemptAndRetainsUnreplayedLegacyFloors() {
        var progress = PlayerProgress()
        progress.levelResults[2] = round("legacy-floor", level: 2, correct: 5, stars: 2, score: 500)
        progress.record(round("best", correct: 6, stars: 3, score: 700))
        progress.record(round("latest", correct: 1, stars: 0, score: 50))
        XCTAssertEqual(progress.recentSummary.levelResults.map(\.id), ["latest", "legacy-floor"])
    }

    func testNoTrendBeforeFourRecordedRounds() {
        let history = (0..<3).map { round("\($0)", correct: 5, day: $0) }
        XCTAssertTrue(ProgressInsights.trends(in: history).isEmpty)
    }

    func testTrendIncludesWeakerRoundsAndShowsAccuracyDecline() throws {
        let history = (0..<4).map { round("\($0)", correct: $0 < 2 ? 6 : 3, day: $0) }
        let trend = try XCTUnwrap(ProgressInsights.trends(in: history).first)
        XCTAssertEqual(trend.roundsCompared, 4)
        XCTAssertEqual(trend.earlier.itemCount, 12)
        XCTAssertEqual(trend.recent.itemCount, 12)
        XCTAssertEqual(trend.accuracyChange, -0.5, accuracy: 0.001)
    }

    func testChangedDifficultyCannotManufactureImprovement() {
        let history = (0..<4).map {
            round("\($0)", correct: $0 < 2 ? 3 : 6, theta: $0 < 2 ? 4 : 1, day: $0)
        }
        XCTAssertTrue(ProgressInsights.trends(in: history).isEmpty)
    }

    func testChangedPuzzleKindOrTimeAllowanceDoesNotProduceComparison() {
        let changedKind = (0..<4).map {
            round("\($0)", correct: 5, kind: $0 < 2 ? .sequence : .arithmetic, day: $0)
        }
        XCTAssertTrue(ProgressInsights.trends(in: changedKind).isEmpty)
        let changedTime = (0..<4).map {
            round("\($0)", correct: 5, limit: $0 < 2 ? 10 : 20, day: $0)
        }
        XCTAssertTrue(ProgressInsights.trends(in: changedTime).isEmpty)
    }

    func testFasterWithLostAccuracyIsNotCalledImprovement() throws {
        let history = (0..<4).map {
            round("\($0)", correct: $0 < 2 ? 6 : 3, elapsed: $0 < 2 ? 8 : 2, day: $0)
        }
        let trend = try XCTUnwrap(ProgressInsights.trends(in: history).first)
        XCTAssertEqual(trend.recent.medianCorrectSeconds, 2)
        XCTAssertFalse(trend.isFasterWithoutAccuracyLoss)
    }

    func testFasterWithSameAccuracyAndNoExtraHintsIsImprovement() throws {
        let history = (0..<4).map {
            round("\($0)", correct: 5, elapsed: $0 < 2 ? 8 : 4, day: $0)
        }
        let trend = try XCTUnwrap(ProgressInsights.trends(in: history).first)
        XCTAssertTrue(trend.isFasterWithoutAccuracyLoss)
    }

    func testExtraHintsPreventUnqualifiedSpeedImprovement() throws {
        let history = (0..<4).map {
            round("\($0)", correct: 5, elapsed: $0 < 2 ? 8 : 4, hints: $0 < 2 ? 0 : 1, day: $0)
        }
        let trend = try XCTUnwrap(ProgressInsights.trends(in: history).first)
        XCTAssertFalse(trend.isFasterWithoutAccuracyLoss)
        XCTAssertEqual(trend.recent.hintsPerItem, 1)
    }

    func testPaceIsUnavailableIfEitherWindowHasNoCorrectAnswers() throws {
        let history = (0..<4).map { round("\($0)", correct: $0 < 2 ? 0 : 6, day: $0) }
        let trend = try XCTUnwrap(ProgressInsights.trends(in: history).first)
        XCTAssertNil(trend.earlier.medianCorrectSeconds)
        XCTAssertNil(trend.recent.medianCorrectSeconds)
        XCTAssertFalse(trend.isFasterWithoutAccuracyLoss)
    }

    func testDuplicateHistoryCannotUnlockTrend() {
        let result = round("same", correct: 5)
        XCTAssertTrue(ProgressInsights.trends(in: [result, result, result, result]).isEmpty)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func round(
        _ id: String, level: Int = 1, correct: Int,
        stars: Int = 1, score: Int = 100, theta: Double = 2,
        kind: PuzzleKind = .sequence, elapsed: Double = 5, limit: Double = 15,
        hints: Int = 0, day: Int = 0
    ) -> LevelResult {
        LevelResult(
            id: id, levelID: level,
            items: (0..<6).map {
                ItemResult(id: "\(id)-\($0)", levelID: level, kind: kind, domain: kind.domain,
                           theta: theta, skillTag: "test", correct: $0 < correct,
                           elapsed: elapsed, timeLimit: limit, hintsUsed: hints)
            },
            stars: stars, score: score, bestStreak: correct,
            completedAt: Date(timeIntervalSince1970: Double(day) * 86400)
        )
    }
}
