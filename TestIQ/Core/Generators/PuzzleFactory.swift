import Foundation

/// Builds the puzzle set for a floor. This is the only place that decides *what* a player
/// sees and in what order, which keeps difficulty progression in one place instead of
/// spread across ten level definitions.
public enum PuzzleFactory {
    /// Builds the items for a floor.
    ///
    /// - Parameters:
    ///   - level: the floor definition.
    ///   - seed: makes the whole run reproducible.
    ///   - abilityOverride: when supplied, adaptive floors bend their difficulty towards
    ///     this θ. This is what makes floor 9 and 10 respond to the player.
    public static func puzzles(
        for level: LevelDefinition, seed: UInt64, abilityOverride: Double? = nil
    ) -> [Puzzle] {
        var generator = SeededGenerator(seed: seed &+ UInt64(level.id) &* 0x9E37_79B9)
        var puzzles: [Puzzle] = []

        for index in 0..<level.itemCount {
            let progress = level.itemCount == 1 ? 1.0 : Double(index) / Double(level.itemCount - 1)
            var theta = level.openingTheta + (level.closingTheta - level.openingTheta) * progress

            if level.isAdaptive, let ability = abilityOverride {
                // Shift the whole ramp by a bounded amount rather than blending toward the
                // player, so the floor's shape is preserved and a strong player genuinely
                // gets harder items instead of the same ones.
                let shift = MathKit.clamp(0.45 * (ability - IQRating.meanTheta) + 0.3, -1.0, 1.2)
                theta = MathKit.clamp(theta + shift, 1.0, 5.2)
            }

            let kind = self.pickKind(for: level, index: index, theta: theta, generator: &generator)
            puzzles.append(
                self.make(kind: kind, theta: theta, level: level, index: index, generator: &generator)
            )
        }
        return puzzles
    }

    public static func make(
        kind: PuzzleKind, theta: Double, level: LevelDefinition, index: Int, generator: inout SeededGenerator
    ) -> Puzzle {
        let id = "L\(level.id)-P\(index)-\(kind.rawValue)"
        switch kind {
        case .sequence, .anagram, .letterRelation, .truthLiar, .ordering,
             .memorySequence, .gridRecall, .rotation, .mirrorImage, .foldedHoles,
             .spatialCount, .matrix, .ratio, .percentage, .rate, .probability, .arithmetic:
            return self.build(kind: kind, theta: theta, id: id, generator: &generator)
        case .oddOneOut:
            return MatrixGenerator.make(kind: .oddOneOut, theta: theta, generator: &generator, id: id)
        }
    }

    private static func build(
        kind: PuzzleKind, theta: Double, id: String, generator: inout SeededGenerator
    ) -> Puzzle {
        switch kind {
        case .sequence:
            return SequenceGenerator.make(theta: theta, generator: &generator, id: id)
        case .anagram, .letterRelation:
            return VerbalGenerator.make(kind: kind, theta: theta, generator: &generator, id: id)
        case .truthLiar, .ordering:
            return LogicGenerator.make(kind: kind, theta: theta, generator: &generator, id: id)
        case .memorySequence, .gridRecall:
            return MemoryGenerator.make(kind: kind, theta: theta, generator: &generator, id: id)
        case .rotation, .mirrorImage, .foldedHoles, .spatialCount:
            return SpatialGenerator.make(kind: kind, theta: theta, generator: &generator, id: id)
        case .matrix, .oddOneOut:
            return MatrixGenerator.make(kind: kind, theta: theta, generator: &generator, id: id)
        case .ratio, .percentage, .rate, .probability, .arithmetic:
            return QuantityGenerator.make(kind: kind, theta: theta, generator: &generator, id: id)
        }
    }

    /// Distributes kinds across a floor so consecutive items rarely repeat, and every kind
    /// in the floor's list gets used at least once when there are enough items.
    private static func pickKind(
        for level: LevelDefinition, index: Int, theta: Double, generator: inout SeededGenerator
    ) -> PuzzleKind {
        var previous: PuzzleKind?
        // Only kinds that can actually express this difficulty are eligible. Without this,
        // a floor whose ramp climbs past a family's ceiling (arithmetic tops out at θ 3.2)
        // would silently produce a mid-floor dip in difficulty, and the scoring engine
        // would read the player's improving accuracy as a decline.
        let reachable = level.puzzleKinds.filter { $0.maxTheta >= theta }
        var pool = (reachable.isEmpty ? level.puzzleKinds : reachable).filter { $0 != previous }
        if pool.isEmpty { pool = level.puzzleKinds }

        if level.puzzleKinds.count > 1 {
            // On the widest floors, take a random kind rather than cycling, so a player
            // does not learn a rhythm and start anticipating the next item type.
            pool = generator.nextBool(probability: 0.55) ? pool : [pool[index % pool.count]]
        }

        let kind = generator.pick(pool)
        previous = kind
        return kind
    }

    // MARK: - Adaptive seeding

    /// A stable per-player seed so replaying a floor does not silently present a
    /// different exam, while a fresh run still feels new.
    public static func seed(for levelID: Int, attempt: Int, sessionSalt: UInt64) -> UInt64 {
        UInt64(levelID) &* 1_000_003 &+ UInt64(attempt &* 7) &+ sessionSalt
    }
}