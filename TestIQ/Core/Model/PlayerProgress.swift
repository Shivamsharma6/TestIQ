import Foundation

/// Earned rewards and actual practice history are separate: a rematch can go worse
/// without erasing a personal best or pretending the weaker round never happened.
struct PlayerProgress: Codable, Equatable {
    var unlockedLevelID: Int = 1
    var levelResults: [Int: LevelResult] = [:]
    var lastAssessment: Assessment?
    var soundEnabled = true
    var hapticsEnabled = true
    var hasSeenIntro = false
    var attemptHistory: [LevelResult] = []
    var earnedStars: [Int: Int] = [:]
    var personalBestScores: [Int: Int] = [:]
    var learnedInteractions: Set<String> = []

    init() {}

    private enum CodingKeys: String, CodingKey {
        case unlockedLevelID, levelResults, lastAssessment, soundEnabled, hapticsEnabled
        case hasSeenIntro, attemptHistory, earnedStars, personalBestScores, learnedInteractions
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        unlockedLevelID = try values.decodeIfPresent(Int.self, forKey: .unlockedLevelID) ?? 1
        levelResults = try values.decodeIfPresent([Int: LevelResult].self, forKey: .levelResults) ?? [:]
        lastAssessment = try values.decodeIfPresent(Assessment.self, forKey: .lastAssessment)
        soundEnabled = try values.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        hapticsEnabled = try values.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        hasSeenIntro = try values.decodeIfPresent(Bool.self, forKey: .hasSeenIntro) ?? false
        // Old saves contain bests, not a timeline. Never invent rounds during migration.
        attemptHistory = try values.decodeIfPresent([LevelResult].self, forKey: .attemptHistory) ?? []
        earnedStars = try values.decodeIfPresent([Int: Int].self, forKey: .earnedStars)
            ?? levelResults.mapValues(\.stars)
        personalBestScores = try values.decodeIfPresent([Int: Int].self, forKey: .personalBestScores)
            ?? levelResults.mapValues(\.score)
        learnedInteractions = try values.decodeIfPresent(Set<String>.self, forKey: .learnedInteractions) ?? []
    }

    func stars(for levelID: Int) -> Int {
        max(earnedStars[levelID] ?? 0, levelResults[levelID]?.stars ?? 0)
    }

    func attempts(for levelID: Int) -> Int { levelResults[levelID]?.attempts ?? 0 }
    func isUnlocked(_ levelID: Int) -> Bool {
        LevelCatalog.level(levelID) != nil && levelID <= unlockedLevelID
    }
    func isCleared(_ levelID: Int) -> Bool { stars(for: levelID) > 0 }
    var totalStars: Int { LevelCatalog.all.reduce(0) { $0 + stars(for: $1.id) } }
    var clearedCount: Int { LevelCatalog.all.filter { isCleared($0.id) }.count }
    var maxStars: Int { LevelCatalog.count * 3 }
    var bestResults: [LevelResult] { levelResults.values.sorted { $0.levelID < $1.levelID } }
    var completedRunCount: Int { attemptHistory.count }
    var nextLevelID: Int {
        LevelCatalog.all.first { !isCleared($0.id) }?.id ?? LevelCatalog.finalLevelID
    }
    var hasFinishedAscent: Bool { clearedCount >= LevelCatalog.count }
    var summary: RunSummary { RunSummary(levelResults: bestResults) }

    /// Recent performance drives coaching. Legacy floors stay available until replayed.
    var recentSummary: RunSummary {
        var latest = levelResults
        for result in attemptHistory { latest[result.levelID] = result }
        return RunSummary(levelResults: Array(latest.values))
    }

    func latestResult(for levelID: Int) -> LevelResult? {
        attemptHistory.last { $0.levelID == levelID } ?? levelResults[levelID]
    }

    func personalBestScore(for levelID: Int) -> Int? {
        (attemptHistory.filter { $0.levelID == levelID }.map(\.score)
            + [levelResults[levelID]?.score, personalBestScores[levelID]].compactMap { $0 }).max()
    }

    mutating func record(_ result: LevelResult) {
        guard LevelCatalog.level(result.levelID) != nil,
              !attemptHistory.contains(where: { $0.id == result.id }) else { return }
        let levelID = result.levelID
        personalBestScores[levelID] = max(personalBestScore(for: levelID) ?? 0, result.score)
        var recorded = result
        recorded.attempts = attempts(for: levelID) + 1
        earnedStars[levelID] = max(stars(for: levelID), result.stars)
        attemptHistory.append(recorded)
        var best = levelResults[levelID]?.bestPerformance(excluding: recorded) ?? recorded
        best.attempts = recorded.attempts
        levelResults[levelID] = best
        if result.isCleared {
            unlockedLevelID = min(LevelCatalog.finalLevelID, max(unlockedLevelID, levelID + 1))
        }
    }
}
