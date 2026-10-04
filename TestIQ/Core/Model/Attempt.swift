import Foundation

/// The outcome of one puzzle, recorded once and then never mutated. Everything the report
/// says is derived from a list of these, which keeps scoring reproducible and auditable.
public struct ItemResult: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let levelID: Int
    public let kind: PuzzleKind
    public let domain: CognitiveDomain
    public let theta: Double
    public let skillTag: String
    public let correct: Bool
    public let elapsed: TimeInterval
    public let timeLimit: TimeInterval
    public let hintsUsed: Int
    /// True when the clock ran out before the player committed to anything.
    public let timedOut: Bool

    public init(
        id: String,
        levelID: Int,
        kind: PuzzleKind,
        domain: CognitiveDomain,
        theta: Double,
        skillTag: String,
        correct: Bool,
        elapsed: TimeInterval,
        timeLimit: TimeInterval,
        hintsUsed: Int,
        timedOut: Bool = false
    ) {
        self.id = id
        self.levelID = levelID
        self.kind = kind
        self.domain = domain
        self.theta = theta
        self.skillTag = skillTag
        self.correct = correct
        self.elapsed = elapsed
        self.timeLimit = timeLimit
        self.hintsUsed = hintsUsed
        self.timedOut = timedOut
    }

    /// Fraction of the allowance used. Clamped so a pause in the middle of the screen
    /// cannot push this past the meaningful range.
    public var elapsedRatio: Double {
        guard self.timeLimit > 0 else { return 1 }
        return MathKit.clamp(Double(self.elapsed) / self.timeLimit, 0, 1.6)
    }
}

/// Everything recorded about one attempt at one floor.
public struct LevelResult: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let levelID: Int
    public let items: [ItemResult]
    public let stars: Int
    public let score: Int
    public let accuracy: Double
    public let bestStreak: Int
    public let completedAt: Date
    /// How many times this floor has been attempted. Carried so the profile can show it.
    public var attempts: Int

    public var isCleared: Bool { self.stars > 0 }
    public var correctCount: Int { self.items.filter(\.correct).count }
    public var duration: TimeInterval { self.items.reduce(0) { $0 + $1.elapsed } }

    public init(
        id: String,
        levelID: Int,
        items: [ItemResult],
        stars: Int,
        score: Int,
        bestStreak: Int,
        completedAt: Date = Date(),
        attempts: Int = 1
    ) {
        self.id = id
        self.levelID = levelID
        self.items = items
        self.stars = stars
        let correct = items.filter(\.correct).count
        self.accuracy = items.isEmpty ? 0 : Double(correct) / Double(items.count)
        self.score = score
        self.bestStreak = bestStreak
        self.completedAt = completedAt
        self.attempts = max(1, attempts)
    }

    public func bestPerformance(excluding other: LevelResult?) -> LevelResult {
        guard let other else { return self }
        if self.accuracy > other.accuracy { return self }
        if self.accuracy == other.accuracy && self.score > other.score { return self }
        return other
    }
}

/// The aggregate of every floor the player has completed. This is the sole input to
/// `ScoringEngine`.
public struct RunSummary: Sendable, Hashable {
    public let levelResults: [LevelResult]

    public init(levelResults: [LevelResult]) {
        self.levelResults = levelResults.sorted { $0.levelID < $1.levelID }
    }

    public var allItems: [ItemResult] { self.levelResults.flatMap(\.items) }

    public var totalItems: Int { self.allItems.count }

    public var overallAccuracy: Double {
        guard self.totalItems > 0 else { return 0 }
        return Double(self.allItems.filter(\.correct).count) / Double(self.totalItems)
    }

    /// Best attempt per floor — the report describes the player's best showing, not their
    /// worst one, so replaying a floor cannot lower a score already earned.
    public var bestByLevel: [LevelResult] {
        Dictionary(grouping: self.levelResults, by: \.levelID)
            .compactMap { $0.value.reduce(nil) { best, candidate in
                best?.bestPerformance(excluding: candidate) ?? candidate
            } }
            .sorted { $0.levelID < $1.levelID }
    }
}