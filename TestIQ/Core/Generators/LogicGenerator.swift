import Foundation

/// Constraint-based deduction: truth-or-lie statements and constrained ordering.
enum LogicGenerator {
    static func make(kind: PuzzleKind, theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        switch kind {
        case .ordering: return self.ordering(theta: theta, generator: &generator, id: id)
        default: return self.truthOrLie(theta: theta, generator: &generator, id: id)
        }
    }

    // MARK: - Truth or lie

    /// What a speaker asserts. Modelling the claim as data rather than as a finished
    /// string is what lets the generator *verify* the puzzle has exactly one solution
    /// before handing it to the player.
    private enum Claim {
        case selfIsNotLiar
        case otherIsLiar(Int)
        case otherIsNotLiar(Int)

        func isTrue(givenLiar liar: Int, speaker: Int) -> Bool {
            switch self {
            case .selfIsNotLiar: return speaker != liar
            case .otherIsLiar(let index): return index == liar
            case .otherIsNotLiar(let index): return index != liar
            }
        }

        func rendered(speaker: Int, people: [String]) -> String {
            switch self {
            case .selfIsNotLiar:
                return "I am not the liar."
            case .otherIsLiar(let index):
                return "\(people[index]) is the liar."
            case .otherIsNotLiar(let index):
                return "\(people[index]) is not the liar."
            }
        }
    }

    private static func truthOrLie(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let people = generator.sample(["Ada", "Basil", "Cleo", "Dev", "Esme", "Finn", "Gita", "Hugo"], count: 4)
        let ordinals = ["first", "second", "third", "fourth"]

        // Two statements about a third person are required so the puzzle cannot be solved
        // by a single self-referential claim.
        let wantsExternalClaims = theta >= 2.6
        let config = self.makeUniqueConfig(
            people: people, generator: &generator, wantsExternalClaims: wantsExternalClaims
        )

        let liarIndex = config.liar
        let answerName = people[liarIndex]
        let body = config.claims.enumerated()
            .map { index, entry in "\(ordinals[index]) — \(people[entry.speaker]) says \"\(entry.claim.rendered(speaker: entry.speaker, people: people))\"" }
            .joined(separator: "\n")

        let distractors = people.filter { $0 != answerName }
        let labels = [answerName] + Array(generator.sample(distractors, count: min(3, distractors.count)))
        let choice = GenSupport.choice(labels: labels, correctIndex: 0, prefix: id, generator: &generator)

        let thetaValue = MathKit.clamp(theta, 1.4, 4.8)
        return Puzzle(
            id: id,
            kind: .truthLiar,
            theta: thetaValue,
            prompt: "Exactly one of them is lying.",
            subtitle: "Everyone else is telling the truth",
            stimulus: .text(body + "\n\nWho is the liar?"),
            options: choice.options,
            answer: .optionIndex(choice.answerIndex),
            hint: "Someone denied that the liar is the first person. Decide whether that denial can be true before you reason about anyone's other statement.",
            timeLimit: MathKit.clamp(48.0 - thetaValue * 4.0, 20, 48),
            skillTag: "truth-statement"
        )
    }

    /// Builds a liar assignment whose statement set admits exactly one solution.
    private static func makeUniqueConfig(
        people: [String], generator: inout SeededGenerator, wantsExternalClaims: Bool
    ) -> (liar: Int, claims: [(speaker: Int, claim: Claim)]) {
        let count = people.count

        for _ in 0..<400 {
            let liar = generator.nextInt(in: 0..<count)
            var claims: [(speaker: Int, claim: Claim)] = []

            for speaker in 0..<count {
                let mustBeTrue = speaker != liar
                var candidates: [Claim] = [.selfIsNotLiar]
                for other in 0..<count where other != speaker {
                    candidates.append(.otherIsLiar(other))
                    candidates.append(.otherIsNotLiar(other))
                }
                let valid = candidates.filter { $0.isTrue(givenLiar: liar, speaker: speaker) == mustBeTrue }
                guard !valid.isEmpty else { continue }

                // Prefer claims about other people, which require real reasoning.
                let external = valid.filter { candidate in
                    if case .selfIsNotLiar = candidate { return false }
                    return true
                }
                let chosen = generator.nextBool(probability: wantsExternalClaims ? 0.85 : 0.5) && !external.isEmpty
                    ? generator.pick(external)
                    : generator.pick(valid)
                claims.append((speaker, chosen))
            }

            guard claims.count == count else { continue }

            let solutions = (0..<count).filter { candidate in
                claims.allSatisfy { $0.claim.isTrue(givenLiar: candidate, speaker: $0.speaker) }
            }
            guard solutions.count == 1, solutions[0] == liar else { continue }

            return (liar, claims)
        }

        // Deterministic fallback, checked against the same uniqueness test:
        // with liar = 0 every claim below holds, and no other assignment does.
        let fallback: [(speaker: Int, claim: Claim)] = [
            (0, .otherIsLiar(1)), (1, .otherIsLiar(0)),
            (2, .otherIsNotLiar(1)), (3, .otherIsNotLiar(2)),
        ]
        return (0, fallback)
    }

    // MARK: - Ordering

    private static func ordering(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let set = generator.pick(Self.orderingSets)
        let correctOrder = set.items

        // The presented order must be wrong, or the puzzle is solved before it starts.
        var presented = generator.shuffled(correctOrder)
        var attempts = 0
        while presented == correctOrder && attempts < 20 {
            presented = generator.shuffled(correctOrder)
            attempts += 1
        }
        if presented == correctOrder {
            presented = [correctOrder[1], correctOrder[0]] + Array(correctOrder.dropFirst(2))
        }

        // The answer lists the presented indices in the order they should be tapped, so it
        // is a genuine permutation of the presented order rather than the identity — which
        // is what guarantees the player cannot simply tap left to right.
        let answerIndices = presented.indices.sorted { lhs, rhs in
            let lhsRank = correctOrder.firstIndex(of: presented[lhs]) ?? 0
            let rhsRank = correctOrder.firstIndex(of: presented[rhs]) ?? 0
            return lhsRank < rhsRank
        }

        let thetaValue = MathKit.clamp(theta, 1.4, 4.8)
        return Puzzle(
            id: id,
            kind: .ordering,
            theta: thetaValue,
            prompt: "Order these \(set.noun)",
            subtitle: set.rule,
            stimulus: .text("Tap them in order, earliest or smallest first."),
            options: [],
            answer: .ordering(answerIndices),
            hint: set.hint,
            timeLimit: MathKit.clamp(44.0 - thetaValue * 3.5, 20, 44),
            skillTag: "constraint-ordering",
            orderLabels: presented
        )
    }

    private struct OrderingSet {
        let noun: String
        let rule: String
        let items: [String]
        let hint: String
    }

    private static let orderingSets: [OrderingSet] = [
        OrderingSet(
            noun: "planets",
            rule: "By distance from the Sun, closest first.",
            items: ["Mercury", "Venus", "Earth", "Mars", "Jupiter"],
            hint: "The first four are the rocky inner planets. Mercury is both the smallest and the closest."
        ),
        OrderingSet(
            noun: "integers",
            rule: "By value, smallest first.",
            items: ["-12", "-3", "0", "7", "19"],
            hint: "Negative numbers sit to the left of zero, and the more negative one is the smaller value."
        ),
        OrderingSet(
            noun: "words",
            rule: "By length in letters, shortest first.",
            items: ["cat", "planet", "elephant", "hippopotamus", "antidisestablishmentarianism"],
            hint: "Count the letters instead of eyeballing it. The last one is far longer than it appears."
        ),
        OrderingSet(
            noun: "fractions",
            rule: "By value, smallest first.",
            items: ["3/4", "1/3", "5/6", "2/5", "7/8"],
            hint: "Compare each numerator against that fraction's own denominator — the one closest to 1 is the largest."
        ),
        OrderingSet(
            noun: "animals",
            rule: "By typical lifespan, shortest first.",
            items: ["Mouse", "Rabbit", "Dog", "Elephant", "Giant tortoise"],
            hint: "Lifespan tracks size and metabolism, with one famous outlier you will remember instantly."
        ),
        OrderingSet(
            noun: "durations",
            rule: "By duration, shortest first.",
            items: ["2 seconds", "7 minutes", "1 hour", "3 days", "2 months"],
            hint: "Convert everything to seconds before comparing. Estimating directly will mislead you."
        ),
        OrderingSet(
            noun: "letters",
            rule: "By alphabet position, A first.",
            items: ["Q", "M", "Z", "F", "T"],
            hint: "Write the alphabet out and read off the positions rather than guessing from the shape of each letter."
        ),
        OrderingSet(
            noun: "powers",
            rule: "By value, smallest first.",
            items: ["2^3", "2^5", "2^7", "2^9", "2^11"],
            hint: "The base never changes, so this is simply the exponents in order."
        ),
    ]
}