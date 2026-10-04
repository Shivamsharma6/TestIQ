import Foundation

/// Working-memory items. Both kinds are `echo` archetype: the player watches a stimulus
/// appear, then reproduces it. Nothing is shown after the presentation window closes, so
/// the item measures recall rather than recognition.
enum MemoryGenerator {
    static func make(kind: PuzzleKind, theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        switch kind {
        case .gridRecall: return self.gridRecall(theta: theta, generator: &generator, id: id)
        default: return self.echoSequence(theta: theta, generator: &generator, id: id)
        }
    }

    // MARK: - Echo sequence

    private static func echoSequence(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let thetaValue = MathKit.clamp(theta, 1.2, 4.2)
        // Digit span of 3 at the easiest item, growing one step per unit of θ.
        let length = MathKit.clamp(Int((3.0 + (thetaValue - 1.2) * 1.1).rounded()), 3, 8)
        let columns = length <= 5 ? 3 : 4
        let rows = Int(ceil(Double(length) / Double(columns)))
        let cellCount = columns * rows

        var sequence: [Int] = []
        var used = Set<Int>()
        while sequence.count < min(length, cellCount) {
            let candidate = generator.nextInt(in: 0..<cellCount)
            if used.insert(candidate).inserted { sequence.append(candidate) }
        }

        return Puzzle(
            id: id,
            kind: .memorySequence,
            theta: thetaValue,
            prompt: "Watch, then repeat",
            subtitle: "\(sequence.count) tiles in order",
            stimulus: .memory(MemorySpec(columns: columns, rows: rows, sequence: sequence)),
            options: [],
            answer: .tapSequence(sequence),
            hint: "Group the flashes into chunks of two or three instead of holding each one separately.",
            timeLimit: MathKit.clamp(10.0 + Double(length) * 2.6, 14, 30),
            skillTag: "echo-span"
        )
    }

    // MARK: - Grid recall

    private static func gridRecall(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let thetaValue = MathKit.clamp(theta, 1.2, 4.0)
        let litCount = MathKit.clamp(Int((2.0 + (thetaValue - 1.2) * 1.35).rounded()), 2, 6)
        let side = thetaValue < 2.4 ? 3 : (thetaValue < 3.4 ? 4 : 5)
        let cellCount = side * side

        var lit: [Int] = []
        var used = Set<Int>()
        while lit.count < min(litCount, cellCount) {
            let candidate = generator.nextInt(in: 0..<cellCount)
            if used.insert(candidate).inserted { lit.append(candidate) }
        }

        return Puzzle(
            id: id,
            kind: .gridRecall,
            theta: thetaValue,
            prompt: "Which tiles were lit?",
            subtitle: "Tap every one of them, in any order",
            stimulus: .memory(MemorySpec(columns: side, rows: side, lit: lit)),
            options: [],
            answer: .tapSequence(lit.sorted()),
            hint: "Say each flash out loud as a position — 'top row, far left' holds up better than 'the one at two o'clock'.",
            timeLimit: MathKit.clamp(12.0 + Double(litCount) * 2.2, 16, 30),
            skillTag: "grid-position"
        )
    }
}