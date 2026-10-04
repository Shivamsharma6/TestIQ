import Foundation

/// Numerical reasoning: ratios, percentages, combined work rates, probability and mental
/// arithmetic. Every question is generated with a known closed-form answer, so nothing
/// here needs to be checked against an external source.
enum QuantityGenerator {
    static func make(kind: PuzzleKind, theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        switch kind {
        case .ratio: return self.ratio(theta: theta, generator: &generator, id: id)
        case .percentage: return self.percentage(theta: theta, generator: &generator, id: id)
        case .rate: return self.rate(theta: theta, generator: &generator, id: id)
        case .probability: return self.probability(theta: theta, generator: &generator, id: id)
        default: return self.arithmetic(theta: theta, generator: &generator, id: id)
        }
    }

    private static func multipleChoice(
        id: String, prompt: String, subtitle: String?, question: String,
        answer: Int, distractors: [Int], hint: String, timeLimit: TimeInterval,
        theta: Double, kind: PuzzleKind, tag: String,
        generator: inout SeededGenerator
    ) -> Puzzle {
        let labels = ([answer] + distractors).map(String.init)
        let choice = GenSupport.choice(labels: labels, correctIndex: 0, prefix: id, generator: &generator)
        return Puzzle(
            id: id,
            kind: kind,
            theta: MathKit.clamp(theta, 1.0, 5.0),
            prompt: prompt,
            subtitle: subtitle,
            stimulus: .text(question),
            options: choice.options,
            answer: .optionIndex(choice.answerIndex),
            hint: hint,
            timeLimit: timeLimit,
            skillTag: tag
        )
    }

    // MARK: - Ratio

    private static func ratio(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let hard = theta >= 3.4
        let a = generator.nextInt(in: hard ? 3...9 : 2...6)
        let b = generator.nextInt(in: 4...12)
        let scale = generator.nextInt(in: 2...4)
        let total = (a + b) * scale
        let answer = a * scale

        let question = "Two quantities are in the ratio \(a) : \(b), and together they make \(total). How much is the first quantity?"
        return self.multipleChoice(
            id: id, prompt: "Solve the ratio", subtitle: nil, question: question,
            answer: answer,
            distractors: GenSupport.distinctValues(excluding: answer, from: [b * scale, total - answer / 2, answer + 1, answer - 1], count: 3),
            hint: "Split \(total) in the ratio \(a):\(b) — add the ratio parts first (\(a + b)), then find one part.",
            timeLimit: 30, theta: theta, kind: .ratio, tag: "ratio-proportion",
            generator: &generator
        )
    }

    // MARK: - Percentage

    private static func percentage(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let percent = generator.pick([12, 15, 18, 20, 25, 30, 40, 60])
        let base = MathKit.roundedMultiple(of: 20, near: generator.nextInt(in: 8...48))
        let increase = generator.nextBool(probability: 0.6)

        if increase {
            let answer = base + base * percent / 100
            let question = "A value of \(base) increases by \(percent)%. What is it now?"
            return self.multipleChoice(
                id: id, prompt: "Apply the percentage", subtitle: "Increases", question: question,
                answer: answer,
                distractors: GenSupport.distinctValues(excluding: answer, from: [base * percent / 100, base - base * percent / 100, base + percent, answer + 10], count: 3),
                hint: "\(percent)% of \(base) is \(base * percent / 100). Add that to \(base) — the base is the original value.",
                timeLimit: 28, theta: theta, kind: .percentage, tag: "percent-change",
                generator: &generator
            )
        } else {
            let answer = base - base * percent / 100
            let question = "A value of \(base) decreases by \(percent)%. What is it now?"
            return self.multipleChoice(
                id: id, prompt: "Apply the percentage", subtitle: "Decreases", question: question,
                answer: answer,
                distractors: GenSupport.distinctValues(excluding: answer, from: [base * percent / 100, base + base * percent / 100, base - percent, answer - 10], count: 3),
                hint: "\(percent)% of \(base) is \(base * percent / 100). Subtract that from \(base).",
                timeLimit: 28, theta: theta, kind: .percentage, tag: "percent-change",
                generator: &generator
            )
        }
    }

    // MARK: - Work rate

    private static func rate(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        // Parameterised so every figure is a whole number of minutes:
        // solo rates of 1/((m+1)k) and 1/(m(m+1)k) sum to exactly 1/(mk).
        let m = generator.nextInt(in: theta >= 3.6 ? 2...4 : 2...3)
        let k = generator.nextInt(in: 2...(theta >= 3.6 ? 8 : 5))
        let together = m * k
        let aloneA = (m + 1) * k
        let aloneB = m * (m + 1) * k

        let question = "Two people can finish a job together in \(together) minutes. "
            + "Working alone, one of them would take \(aloneA) minutes. How many minutes would the other take working alone?"

        return self.multipleChoice(
            id: id,
            prompt: "Combined work rate",
            subtitle: nil,
            question: question,
            answer: aloneB,
            distractors: GenSupport.distinctValues(excluding: aloneB, from: [together, aloneA * 2, aloneB / 2, aloneA + together, together * 2], count: 3),
            hint: "Rates add, times do not. If together takes \(together) minutes the combined rate is 1/\(together) per minute. Subtract A's rate of 1/\(aloneA) from it, then invert what is left.",
            timeLimit: MathKit.clamp(46.0 - theta * 3.5, 24, 46),
            theta: theta,
            kind: .rate,
            tag: "work-rate",
            generator: &generator
        )
    }

    // MARK: - Probability

    private static func probability(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let useDice = theta < 3.2 || generator.nextBool()
        if useDice {
            let target = generator.pick([5, 6, 7, 8, 9, 10, 11, 12])
            let favourable = 6 - abs(target - 7)
            let total = 36
            let percent = (favourable * 100) / total
            let reduced = MathKit.simplify(favourable, total)
            let question = "Two fair six-sided dice are rolled. What is the probability that the total is \(target)?"
            return self.multipleChoice(
                id: id, prompt: "Find the probability", subtitle: "\(reduced.0)/\(reduced.1)", question: question,
                answer: percent,
                distractors: GenSupport.distinctValues(excluding: percent, from: [(favourable * 100) / 6, (6 - abs(target - 7)) * 10, (favourable * 50) / total], count: 3),
                hint: "Count the winning combinations out of 36, then convert to a percentage.",
                timeLimit: 34, theta: theta, kind: .probability, tag: "probability-space",
                generator: &generator
            )
        }

        // Marble bag: enumerate the sample space rather than reasoning about proportions.
        let red = generator.nextInt(in: 2...6)
        let blue = generator.nextInt(in: 2...6)
        let total = red + blue
        let targetRed = generator.nextBool(probability: 0.5)
        let favourable = targetRed ? red : blue
        let percent = (favourable * 100) / total
        let colour = targetRed ? "red" : "blue"
        let question = "A bag holds \(red) red and \(blue) blue marbles. One is drawn at random. What percentage chance is it \(colour)?"
        return self.multipleChoice(
            id: id, prompt: "Find the probability", subtitle: "Express as a percentage", question: question,
            answer: percent,
            distractors: GenSupport.distinctValues(excluding: percent, from: [(red * 100) / (red + blue + 1), (blue * 100) / red, percent + 5, percent - 5], count: 3),
            hint: "Favourable marbles divided by total marbles, then multiply by 100. The denominator is every marble in the bag.",
            timeLimit: 30, theta: theta, kind: .probability, tag: "probability-space",
            generator: &generator
        )
    }

    // MARK: - Mental arithmetic

    private static func arithmetic(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let maxOperand = Int(MathKit.clamp(6 + theta * 5, 8, 40))
        let operation = generator.nextInt(in: 0..<3)
        let a = generator.nextInt(in: 2...maxOperand)
        let b = generator.nextInt(in: 2...maxOperand)

        switch operation {
        case 0:
            let answer = a + b
            return self.multipleChoice(
                id: id, prompt: "Quick maths", subtitle: "Add", question: "\(a) + \(b) = ?",
                answer: answer,
                distractors: GenSupport.distinctValues(excluding: answer, from: [a * b, a - b, answer + 2], count: 3),
                hint: "Round one of them to a friendly number, then correct.",
                timeLimit: 14, theta: theta, kind: .arithmetic, tag: "mental-arithmetic",
                generator: &generator
            )
        case 1:
            let high = max(a, b)
            let low = min(a, b)
            let answer = high - low
            return self.multipleChoice(
                id: id, prompt: "Quick maths", subtitle: "Subtract", question: "\(high) − \(low) = ?",
                answer: answer,
                distractors: GenSupport.distinctValues(excluding: answer, from: [high + low, high - 1, answer + 10], count: 3),
                hint: "Count up from the smaller number to the larger one.",
                timeLimit: 14, theta: theta, kind: .arithmetic, tag: "mental-arithmetic",
                generator: &generator
            )
        default:
            let product = a * b
            let answer = product / 2
            return self.multipleChoice(
                id: id, prompt: "Quick maths", subtitle: "Half of a product", question: "What is half of \(a) × \(b)?",
                answer: answer,
                distractors: GenSupport.distinctValues(excluding: answer, from: [product, answer * 2, a + b], count: 3),
                hint: "Halving first is easier than multiplying first: \(a) × \(b) ÷ 2 = \(a) × \(b / 2) where possible.",
                timeLimit: 18, theta: theta, kind: .arithmetic, tag: "mental-arithmetic",
                generator: &generator
            )
        }
    }
}