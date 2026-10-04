import Foundation

/// Star thresholds, kept in `Core` rather than inside the view model.
///
/// These are the only real decisions made at the end of a run, and they decide what the
/// player is rewarded for. Putting them next to the scoring maths means they can be tested
/// directly instead of being asserted through a SwiftUI view.
public enum StarRules {
    /// Three stars demands accuracy *and* pace, so it cannot be earned by deliberating:
    /// a run has to be both right and quick.
    public static let threeStarAccuracy = 0.88
    public static let threeStarClockRemaining = 0.45
    public static let twoStarAccuracy = 0.75

    public static func evaluate(
        items: [ItemResult], level: LevelDefinition, score: Int, bestStreak: Int
    ) -> LevelResult {
        guard !items.isEmpty else {
            return LevelResult(
                id: "L\(level.id)-empty", levelID: level.id, items: [],
                stars: 0, score: 0, bestStreak: bestStreak
            )
        }

        let correct = items.filter(\.correct).count
        let accuracy = Double(correct) / Double(items.count)
        let total = items.reduce(0.0) { $0 + $1.timeLimit }
        let clockLeft = total > 0
            ? items.reduce(0.0) { $0 + max(0, $1.timeLimit - $1.elapsed) } / total
            : 0

        var stars = 0
        if accuracy >= level.starGate { stars = 1 }
        if accuracy >= Self.twoStarAccuracy { stars = 2 }
        if accuracy >= Self.threeStarAccuracy && clockLeft >= Self.threeStarClockRemaining { stars = 3 }

        return LevelResult(
            id: "L\(level.id)-\(UUID().uuidString)",
            levelID: level.id, items: items, stars: stars, score: score, bestStreak: bestStreak
        )
    }
}
