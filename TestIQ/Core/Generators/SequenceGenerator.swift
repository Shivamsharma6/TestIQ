import Foundation

/// Number sequences. The family is selected from the requested θ so that a level's
/// difficulty ramp is expressed in the item itself rather than only in a label — every
/// generator in this game does the same thing.
enum SequenceGenerator {
    /// The rule families, ordered by the θ at which each becomes available.
    enum Family: CaseIterable {
        case arithmetic
        case geometric
        case alternatingSums
        case recursiveSum
        case quadratic
        case alternatingGrowth
        case primes
        case geometricOffset
        case interleavedGeometric

        /// Lowest θ at which this family is used.
        var minTheta: Double {
            switch self {
            case .arithmetic: return 1.0
            case .geometric: return 1.8
            case .alternatingSums: return 2.2
            case .recursiveSum: return 3.0
            case .quadratic: return 2.8
            case .alternatingGrowth: return 3.4
            case .primes: return 3.6
            case .geometricOffset: return 4.2
            case .interleavedGeometric: return 4.4
            }
        }

        var tag: String {
            switch self {
            case .arithmetic: return "arithmetic-step"
            case .geometric: return "geometric-ratio"
            case .alternatingSums: return "alternating-difference"
            case .recursiveSum: return "recursive-sum"
            case .quadratic: return "quadratic"
            case .alternatingGrowth: return "alternating-growth"
            case .primes: return "prime-sequence"
            case .geometricOffset: return "geometric-offset"
            case .interleavedGeometric: return "interleaved-geometric"
            }
        }

        var options: [Double] {
            switch self {
            case .arithmetic: return [3, 4]
            case .geometric: return [4]
            case .alternatingSums: return [4]
            case .recursiveSum: return [4]
            case .quadratic: return [4]
            case .alternatingGrowth: return [4]
            case .primes: return [4]
            case .geometricOffset: return [4]
            case .interleavedGeometric: return [4]
            }
        }

        static func eligible(at theta: Double) -> [Family] {
            self.allCases.filter { $0.minTheta <= theta }
        }
    }

    static func make(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let clamped = MathKit.clamp(theta, 1.0, 5.2)
        let eligible = Family.eligible(at: clamped)
        let family = eligible.isEmpty ? Family.arithmetic : generator.pick(eligible)

        let built = self.build(family: family, theta: clamped, generator: &generator)
        let answer = built.next

        var candidates = built.temptations
        candidates += [answer - 1, answer + 1, answer + 2, answer - 2]
        let distractors = GenSupport.distinctValues(excluding: answer, from: candidates, count: 3)

        let labels = ([answer] + distractors).map(String.init)
        let choice = GenSupport.choice(
            labels: labels, correctIndex: 0, prefix: id, generator: &generator
        )

        return Puzzle(
            id: id,
            kind: .sequence,
            theta: clamped,
            prompt: "What comes next?",
            subtitle: "Follow the rule, not the rhythm",
            stimulus: .numbers(built.terms),
            options: choice.options,
            answer: .optionIndex(choice.answerIndex),
            hint: built.hint,
            timeLimit: MathKit.clamp(30.0 - clamped * 3.0, 14, 28),
            skillTag: family.tag
        )
    }

    // MARK: - Construction

    private struct Built {
        var terms: [Int]
        var next: Int
        var hint: String
        /// Values the rule could plausibly produce if misread — used as distractors.
        var temptations: [Int]
    }

    private static func build(family: Family, theta: Double, generator: inout SeededGenerator) -> Built {
        switch family {
        case .arithmetic: return self.arithmetic(generator: &generator)
        case .geometric: return self.geometric(theta: theta, generator: &generator)
        case .alternatingSums: return self.alternatingSums(generator: &generator)
        case .recursiveSum: return self.recursiveSum(generator: &generator)
        case .quadratic: return self.quadratic(generator: &generator)
        case .alternatingGrowth: return self.alternatingGrowth(generator: &generator)
        case .primes: return self.primes(generator: &generator)
        case .geometricOffset: return self.geometricOffset(generator: &generator)
        case .interleavedGeometric: return self.interleavedGeometric(generator: &generator)
        }
    }

    private static func arithmetic(generator: inout SeededGenerator) -> Built {
        let ascending = generator.nextBool(probability: 0.75)
        let step = ascending ? generator.nextInt(in: 2...11) : -generator.nextInt(in: 2...9)
        let start = ascending ? generator.nextInt(in: 1...24) : generator.nextInt(in: 40...90)
        var terms: [Int] = []
        for index in 0..<5 { terms.append(start + index * step) }
        let next = start + 5 * step
        return Built(
            terms: terms, next: next,
            hint: "Take the difference between each pair of neighbours. It never changes.",
            temptations: [terms[3] + step * 2, terms[3] + (ascending ? 1 : -1), start + 4 * step + (ascending ? -1 : 1)]
        )
    }

    private static func geometric(theta: Double, generator: inout SeededGenerator) -> Built {
        let ratio = generator.nextInt(in: 2...3)
        let start = generator.nextInt(in: 1...5)
        var terms: [Int] = []
        for _ in 0..<5 { terms.append(terms.last.map { $0 * ratio } ?? start) }
        let next = (terms.last ?? start) * ratio
        return Built(
            terms: terms, next: next,
            hint: "Divide each term by the one before it. The ratio is always the same.",
            temptations: [next + ratio, next - ratio, (terms.last ?? start) + ratio]
        )
    }

    private static func alternatingSums(generator: inout SeededGenerator) -> Built {
        let first = generator.nextInt(in: 2...9)
        var second = generator.nextInt(in: 2...9)
        if second == first { second = first + 2 }
        let start = generator.nextInt(in: 1...18)
        var terms = [start]
        for index in 0..<4 {
            let step = index.isMultiple(of: 2) ? first : second
            terms.append((terms.last ?? start) + step)
        }
        let last = terms.last ?? start
        let next = last + first
        return Built(
            terms: terms, next: next,
            hint: "Write the jumps on their own line. They alternate between two values.",
            temptations: [last + second, last + first + second, last]
        )
    }

    private static func recursiveSum(generator: inout SeededGenerator) -> Built {
        let a = generator.nextInt(in: 1...6)
        let b = a + generator.nextInt(in: 1...6)
        var terms = [a, b]
        while terms.count < 5 { terms.append((terms[terms.count - 1]) + terms[terms.count - 2]) }
        let next = terms[3] + terms[4]
        return Built(
            terms: terms, next: next,
            hint: "Every term from the third onwards is the sum of the two before it.",
            temptations: [terms[3] + terms[2], next + 1, next - 1]
        )
    }

    private static func quadratic(generator: inout SeededGenerator) -> Built {
        let start = generator.nextInt(in: 1...12)
        let firstStep = generator.nextInt(in: 1...5)
        let growth = generator.nextInt(in: 2...5)
        var terms = [start]
        var step = firstStep
        for _ in 0..<4 {
            terms.append((terms.last ?? start) + step)
            step += growth
        }
        let last = terms.last ?? start
        let next = last + (firstStep + 4 * growth)
        return Built(
            terms: terms, next: next,
            hint: "Ladder the differences: the gaps grow by a constant amount each time.",
            temptations: [last + (firstStep + 3 * growth), last + step, last + (firstStep + 5 * growth)]
        )
    }

    private static func alternatingGrowth(generator: inout SeededGenerator) -> Built {
        // Two interleaved arithmetic runs. Reading the whole list as one sequence is the
        // trap, which is exactly the error this tag exists to detect.
        let startA = generator.nextInt(in: 1...15)
        let startB = startA + generator.nextInt(in: 4...11)
        let stepA = generator.nextInt(in: 3...7)
        let stepB = generator.nextInt(in: 2...6)
        if stepA == stepB { }
        let second = stepA == stepB ? stepB + 3 : stepB
        var terms: [Int] = []
        for index in 0..<5 {
            if index.isMultiple(of: 2) {
                terms.append(startA + (index / 2) * stepA)
            } else {
                terms.append(startB + ((index - 1) / 2) * second)
            }
        }
        let last = terms[4]
        let next = startA + 2 * stepA + second
        return Built(
            terms: terms, next: next,
            hint: "Split the list into two runs: take every other term and look at each run on its own.",
            temptations: [last + second, last + stepA, startB + 2 * second]
        )
    }

    private static func primes(generator: inout SeededGenerator) -> Built {
        let primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47]
        let start = generator.nextInt(in: 0...4)
        let slice = Array(primes[start..<(start + 5)])
        let next = primes[start + 5]
        return Built(
            terms: slice, next: next,
            hint: "Check each number for divisors other than 1 and itself. 1 is not prime.",
            temptations: [next + 2, next + 4, slice[3] + 6]
        )
    }

    private static func geometricOffset(generator: inout SeededGenerator) -> Built {
        let offset = generator.nextInt(in: 1...4)
        let start = generator.nextInt(in: 3...9)
        var terms: [Int] = []
        for _ in 0..<5 { terms.append(((terms.last ?? start) * 2) - offset) }
        let next = ((terms.last ?? start) * 2) - offset
        return Built(
            terms: terms, next: next,
            hint: "Double each term, then subtract the same small number every time.",
            temptations: [next + offset, next - offset, (terms.last ?? start) * 2]
        )
    }

    private static func interleavedGeometric(generator: inout SeededGenerator) -> Built {
        let startA = generator.nextInt(in: 1...4)
        let ratioA = generator.nextInt(in: 2...3)
        var valueB = generator.nextInt(in: 30...70)
        let ratioB = generator.nextInt(in: 2...3)

        var terms: [Int] = []
        var currentA = startA
        for index in 0..<5 {
            if index.isMultiple(of: 2) {
                terms.append(currentA)
                currentA *= ratioA
            } else {
                terms.append(valueB)
                valueB = Int((Double(valueB) * Double(ratioB)).rounded())
            }
        }
        let next = currentA
        return Built(
            terms: terms, next: next,
            hint: "Two separate series are interleaved here. Take the terms in odd positions and read them alone.",
            temptations: [next + startA, next * 2, terms[3] / 2]
        )
    }
}