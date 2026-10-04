import Foundation

/// Abstract reasoning: progressive matrices, and shape-based odd-one-out.
enum MatrixGenerator {
    static func make(kind: PuzzleKind, theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        kind == .oddOneOut ? self.oddOneOut(theta: theta, generator: &generator, id: id)
                           : self.matrix(theta: theta, generator: &generator, id: id)
    }

    // MARK: - Progressive matrix

    private static func matrix(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let thetaValue = MathKit.clamp(theta, 1.6, 5.2)
        let rule = self.pickRule(theta: thetaValue, generator: &generator)
        let solution = self.build(rule: rule, generator: &generator)
        let missing = solution.missingIndex

        var cells: [ShapeSpec?] = solution.specs
        cells[missing] = nil
        let spec = MatrixSpec(cells: cells, rule: rule)

        // Distractors differ from the answer in one or two attributes, so every wrong
        // choice encodes a specific misreading of the rule rather than being noise.
        var candidates: [ShapeSpec] = solution.misreadings.map {
            solution.answer.with(fill: $0.fill, rotation: $0.rotation)
        }
        candidates += solution.answer.neighbours()
        let specs = GenSupport.uniqueShapes(answer: solution.answer, candidates: candidates, total: 6)

        let choice = GenSupport.shapeChoice(specs, correctIndex: 0, prefix: id, generator: &generator)

        return Puzzle(
            id: id,
            kind: .matrix,
            theta: thetaValue,
            prompt: "Which piece completes the grid?",
            subtitle: "Exactly one cell is missing",
            stimulus: .matrix(spec),
            options: choice.options,
            answer: .optionIndex(choice.answerIndex),
            hint: solution.hint,
            timeLimit: MathKit.clamp(52.0 - thetaValue * 5.0, 22, 52),
            skillTag: solution.tag
        )
    }

    private struct Misreading {
        var rotation: Int
        var fill: ShapeSpec.Fill
    }

    private struct Solution {
        var specs: [ShapeSpec]
        var answer: ShapeSpec
        var missingIndex: Int
        var misreadings: [Misreading]
        var hint: String
        var tag: String
    }

    private static func pickRule(theta: Double, generator: inout SeededGenerator) -> MatrixSpec.Rule {
        // Row-and-column needs two attributes tracked at once, so it is reserved for the
        // harder end of the range.
        if theta >= 4.0 && generator.nextBool(probability: 0.5) { return .rowAndColumn }
        let pool: [MatrixSpec.Rule] = theta < 2.6
            ? [.rowProgress, .columnProgress]
            : [.rowProgress, .columnProgress, .alternating, .rowAndColumn]
        return generator.pick(pool)
    }

    private static func build(rule: MatrixSpec.Rule, generator: inout SeededGenerator) -> Solution {
        // The matrix rules all step the rotation attribute, so the shape has to be one
        // where a quarter turn is actually visible.
        let base = ShapeSpec(
            shape: generator.pick(ShapeGeometry.rotationSensitive),
            fill: generator.pick([.solid, .hollow, .dotted, .striped]),
            rotation: generator.pick([0, 45, 135, 225, 315]),
            arrangement: .single
        )
        let step = generator.pick([90, 180, 270])
        let otherStep = generator.pick([90, 180, 270].filter { $0 != step })

        var specs: [ShapeSpec] = Array(repeating: base, count: 9)
        let missingIndex: Int

        switch rule {
        case .rowProgress, .columnProgress:
            missingIndex = 8
            for index in 0..<9 {
                let along = rule == .rowProgress ? index % 3 : index / 3
                specs[index] = base.with(rotation: (base.rotation + along * step) % 360)
            }
        case .rowAndColumn:
            missingIndex = 8
            // Two attributes move at once: the shape steps down each row, the angle
            // steps across each column.
            let baseShapes = ShapeGeometry.rotationSensitive
            let baseShapeIndex = baseShapes.firstIndex(of: base.shape) ?? 0
            for row in 0..<3 {
                for column in 0..<3 {
                    specs[row * 3 + column] = ShapeSpec(
                        shape: baseShapes[(baseShapeIndex + row) % baseShapes.count],
                        fill: base.fill,
                        rotation: (base.rotation + column * step) % 360,
                        arrangement: .single
                    )
                }
            }
        case .alternating:
            missingIndex = 8
            let first = base.with(rotation: base.rotation)
            let second = base.with(rotation: (base.rotation + otherStep) % 360)
            for row in 0..<3 {
                for column in 0..<3 {
                    specs[row * 3 + column] = (column.isMultiple(of: 2)) ? first : second
                }
            }
        }

        let answer = specs[missingIndex]
        return Solution(
            specs: specs,
            answer: answer,
            missingIndex: missingIndex,
            misreadings: self.misreadings(for: answer, step: step, otherStep: otherStep, generator: &generator),
            hint: self.hint(for: rule),
            tag: rule == .rowAndColumn ? "matrix-attribute" : "matrix-rule"
        )
    }

    /// The specific wrong answers a rushed player is likely to choose: the angle one step
    /// short, the angle one step over, and the un-rotated base.
    private static func misreadings(
        for answer: ShapeSpec, step: Int, otherStep: Int, generator: inout SeededGenerator
    ) -> [Misreading] {
        let fills = ShapeSpec.Fill.allCases.filter { $0 != answer.fill }
        return [
            Misreading(rotation: (answer.rotation - step + 360) % 360, fill: answer.fill),
            Misreading(rotation: (answer.rotation + step) % 360, fill: answer.fill),
            Misreading(rotation: answer.rotation, fill: generator.pick(fills)),
            Misreading(rotation: (answer.rotation + otherStep) % 360, fill: answer.fill),
            Misreading(rotation: (answer.rotation + 180) % 360, fill: generator.pick(fills)),
        ]
    }

    private static func hint(for rule: MatrixSpec.Rule) -> String {
        switch rule {
        case .rowProgress: return "Read across each row. One attribute steps by the same amount every time."
        case .columnProgress: return "Read down each column instead of across. One attribute steps by the same amount every time."
        case .rowAndColumn: return "Two attributes are moving at once: one changes across each row, the other down each column."
        case .alternating: return "Each row alternates between the same two pieces, starting from the same one."
        }
    }

    // MARK: - Shape odd-one-out

    private static func oddOneOut(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let rule = generator.pick(["rotation", "fill", "shape", "arrangement"]) as String
        let base = ShapeSpec.random(
            generator: &generator,
            shapes: ShapeGeometry.rotationSensitive,
            fills: [.solid, .hollow, .dotted, .striped],
            arrangements: [.single, .row]
        )

        var members: [ShapeSpec] = []
        var odd = base

        switch rule {
        case "rotation":
            members = (0..<4).map { base.with(rotation: (base.rotation + $0 * 90) % 360) }
            odd = base.with(rotation: (base.rotation + 45) % 360)
        case "fill":
            let fills = generator.shuffled(ShapeSpec.Fill.allCases)
            members = fills.prefix(4).map { base.with(fill: $0) }
            let others = ShapeGeometry.rotationSensitive.filter { $0 != base.shape }
            odd = base.with(shape: generator.pick(others))
        case "shape":
            let shapes = generator.shuffled(ShapeGeometry.rotationSensitive)
            members = shapes.prefix(4).map { base.with(shape: $0) }
            odd = base.with(shape: shapes[4], rotation: (base.rotation + 45) % 360)
        default:
            members = (0..<4).map { base.with(arrangement: .row, count: $0 + 1) }
            odd = base.with(arrangement: .single, count: 2)
        }

        // Re-derive the answer's position after uniquing so the correct option is never
        // dropped as a duplicate.
        let specs = GenSupport.uniqueShapes(answer: odd, candidates: members, total: members.count + 1)
        let choice = GenSupport.shapeChoice(
            specs, correctIndex: specs.firstIndex(of: odd) ?? 0, prefix: id, generator: &generator
        )

        return Puzzle(
            id: id,
            kind: .oddOneOut,
            theta: MathKit.clamp(theta, 1.0, 4.4),
            prompt: "Which shape does not belong?",
            subtitle: "Compare every shape, not just the first few",
            stimulus: .text("Find the one that breaks the shared pattern."),
            options: choice.options,
            answer: .optionIndex(choice.answerIndex),
            hint: "Compare one attribute at a time across all the shapes before deciding.",
            timeLimit: 26,
            skillTag: "shape-property"
        )
    }
}

extension ShapeSpec {
    /// Plausible near-misses for a shape: single-attribute changes.
    func neighbours() -> [ShapeSpec] {
        [
            self.with(rotation: (self.rotation + 45) % 360),
            self.with(rotation: (self.rotation + 90) % 360),
            self.with(fill: self.fill == .solid ? .hollow : .solid),
            self.with(handed: -self.handed),
            self.with(shape: self.shape == .square ? .triangle : .square),
        ]
    }
}