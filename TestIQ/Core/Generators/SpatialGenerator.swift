import Foundation

/// Spatial reasoning: rotation, mirroring, unfolding and counting. Every item is
/// expressed with `ShapeSpec`, so the renderer draws it and the generator verifies it
/// without any bitmap ever existing.
enum SpatialGenerator {
    static func make(kind: PuzzleKind, theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        switch kind {
        case .mirrorImage: return self.mirrorImage(theta: theta, generator: &generator, id: id)
        case .foldedHoles: return self.foldedHoles(theta: theta, generator: &generator, id: id)
        case .spatialCount: return self.spatialCount(theta: theta, generator: &generator, id: id)
        default: return self.rotation(theta: theta, generator: &generator, id: id)
        }
    }

    // MARK: - Rotation

    private static func rotation(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        // Only shapes whose silhouette changes under a 90° turn. A cross or a square
        // looks identical after rotation, so an item built from one has neither a
        // visible rule nor a distinguishable answer.
        let target = ShapeSpec(
            shape: generator.pick(ShapeGeometry.rotationSensitive),
            fill: generator.pick([.solid, .hollow, .halfTop]),
            rotation: generator.pick([0, 45, 90, 135]),
            arrangement: generator.nextBool(probability: 0.4) ? .row : .single,
            count: generator.nextBool(probability: 0.35) ? 2 : 1
        )
        let targetRotation = generator.pick([90, 180, 270])

        // The true answer is the same shape at a different angle; distractors are the
        // wrong angle, the mirrored version, and a different shape.
        let correct = target.with(rotation: (target.rotation + targetRotation) % 360)
        let specs = GenSupport.uniqueShapes(
            answer: correct,
            candidates: [
                target.with(rotation: target.rotation),
                target.with(rotation: (correct.rotation + 180) % 360),
                target.with(rotation: (correct.rotation + 90) % 360),
                target.with(shape: generator.pick(ShapeSpec.Shape.allCases), rotation: correct.rotation),
            ],
            total: 4
        )
        let choice = GenSupport.shapeChoice(specs, correctIndex: 0, prefix: id, generator: &generator)

        return Puzzle(
            id: id,
            kind: .rotation,
            theta: MathKit.clamp(theta, 1.5, 4.5),
            prompt: "Which one is the same shape, turned?",
            subtitle: "\(targetRotation)° clockwise",
            stimulus: .shape(target),
            options: choice.options,
            answer: .optionIndex(choice.answerIndex),
            hint: "Pick one distinctive feature and track only where it lands. Turning the whole figure at once loses it.",
            timeLimit: 28,
            skillTag: "rotation-angle"
        )
    }

    // MARK: - Mirror image

    private static func mirrorImage(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        // A symmetric shape would mirror to itself, making the item unanswerable.
        let target = ShapeSpec(
            shape: generator.pick(ShapeGeometry.handed),
            fill: generator.pick([.solid, .hollow, .halfTop]),
            rotation: generator.pick([0, 45, 90, 135, 180, 225, 270, 315]),
            arrangement: .single,
            count: 1
        )

        // A mirror flips handedness and leaves handedness alone — that is the whole test.
        let mirrored = target.with(handed: -target.handed)
        let specs = GenSupport.uniqueShapes(
            answer: mirrored,
            candidates: [
                target,
                target.with(rotation: (target.rotation + 180) % 360, handed: -target.handed),
                target.with(shape: generator.pick(ShapeSpec.Shape.allCases), handed: -target.handed),
                target.with(rotation: (target.rotation + 90) % 360),
            ],
            total: 4
        )

        let choice = GenSupport.shapeChoice(specs, correctIndex: 0, prefix: id, generator: &generator)

        return Puzzle(
            id: id,
            kind: .mirrorImage,
            theta: MathKit.clamp(theta, 1.8, 4.5),
            prompt: "Which one is the mirror image?",
            subtitle: "Flipped left to right",
            stimulus: .shape(target),
            options: choice.options,
            answer: .optionIndex(choice.answerIndex),
            hint: "A mirror reverses handedness but does not change the angle. If a shape has a definite left side, its mirror has the opposite one.",
            timeLimit: 26,
            skillTag: "mirror-handedness"
        )
    }

    // MARK: - Unfolding

    /// One or two folds, holes punched through every layer, and the player picks the
    /// unfolded pattern. Unfolded positions are computed by reflecting through each fold
    /// line in reverse order, which is the only order that makes the reflections stack.
    private static func foldedHoles(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let side = generator.nextInt(in: 4...5)
        let foldCount = theta >= 3.4 ? (generator.nextBool(probability: 0.65) ? 2 : 1) : 1
        let quadrant = side / 2

        // Punches land in one quadrant of the folded packet. Unfolding reflects each
        // punch across the vertical fold line and then, for two folds, across the
        // horizontal one. Reflecting in that order is what makes the layers stack.
        let punchCount = MathKit.clamp(Int((1.0 + theta).rounded()), 2, 3)
        var punches: [Int] = []
        var unfolded = Set<Int>()

        for _ in 0..<punchCount {
            let row = generator.nextInt(in: 0..<quadrant)
            let column = generator.nextInt(in: 0..<quadrant)
            let cell = row * side + column
            guard !punches.contains(cell) else {
                return self.foldedHoles(theta: theta, generator: &generator, id: id)
            }
            punches.append(cell)

            let mirroredColumn = side - 1 - column
            unfolded.insert(cell)
            unfolded.insert(row * side + mirroredColumn)
            if foldCount == 2 {
                let mirroredRow = side - 1 - row
                unfolded.insert(mirroredRow * side + column)
                unfolded.insert(mirroredRow * side + mirroredColumn)
            }
        }

        let correctIndices = unfolded.sorted()
        let distractorIndices = self.unfoldedDistractors(
            correct: correctIndices, side: side, folds: foldCount, generator: &generator
        )

        let choices: [MatrixSpec] = (distractorIndices + [correctIndices]).map { indices in
            var cells = [ShapeSpec?](repeating: nil, count: side * side)
            for index in indices { cells[index] = ShapeSpec(shape: .circle, fill: .solid) }
            return MatrixSpec(cells: cells, rule: .rowProgress)
        }
        let choice = GenSupport.matrixChoice(
            choices, correctIndex: choices.count - 1, prefix: id, generator: &generator
        )

        let foldDescription = foldCount == 1
            ? "The square is folded once along the vertical centre line."
            : "The square is folded along the vertical centre line, then the horizontal centre line."
        let holeDescription = (punchCount == 1 ? "One hole is" : "\(punchCount) holes are")
            + " punched through every layer of the folded packet, at "
            + punches.map { "row \(($0 / side) + 1), column \(($0 % side) + 1)" }.joined(separator: "; ")
            + "."

        return Puzzle(
            id: id,
            kind: .foldedHoles,
            theta: MathKit.clamp(theta, 1.5, 5.0),
            prompt: "Unfold the paper. Where are the holes?",
            subtitle: foldCount == 1 ? "One fold" : "Two folds",
            stimulus: .text(foldDescription + "\n" + holeDescription),
            options: choice.options,
            answer: .optionIndex(choice.answerIndex),
            hint: "Undo the folds in reverse order. Each unfold mirrors every hole across that fold line, so the count multiplies at every step.",
            timeLimit: MathKit.clamp(50.0 - theta * 4.0, 24, 50),
            skillTag: "fold-symmetry"
        )
    }

    /// Near-miss hole patterns, each representing a specific miscounting of the layers:
    /// a single hole shifted off the fold line, or a spurious mirrored pair.
    private static func unfoldedDistractors(
        correct: [Int], side: Int, folds: Int, generator: inout SeededGenerator
    ) -> [[Int]] {
        var result: [[Int]] = []
        var seen: Set<Set<Int>> = [Set(correct)]

        // The "forgot to mirror one hole" error.
        if let anchor = correct.first {
            let shifted = (anchor % side == 0) ? anchor + 1 : anchor - 1
            let candidate = Array(Set(correct.map { $0 == anchor ? shifted : $0 }))
            if candidate.count == correct.count, seen.insert(Set(candidate)).inserted {
                result.append(candidate.sorted())
            }
        }

        // The "one layer too many" error: an extra mirror-symmetric pair.
        var cell = 0
        while result.count < 3 && cell < side * side {
            let row = cell / side
            let column = cell % side
            cell += 1
            let pair = [row * side + column, row * side + (side - 1 - column)]
            let candidate = Array(Set(correct + pair))
            if candidate.count > correct.count, seen.insert(Set(candidate)).inserted {
                result.append(candidate.sorted())
            }
        }

        // Last resort: any genuinely different pattern.
        var attempts = 0
        while result.count < 3 && attempts < 8 {
            attempts += 1
            let mirrored = correct.map { ($0 / side) * side + (side - 1 - ($0 % side)) }
            let candidate = Array(Set(mirrored))
            if Set(candidate) != Set(correct), seen.insert(Set(candidate)).inserted {
                result.append(candidate.sorted())
            }
            let trimmed = Array(Set(correct.dropLast()))
            if !trimmed.isEmpty, Set(trimmed) != Set(correct), seen.insert(Set(trimmed)).inserted {
                result.append(trimmed.sorted())
            }
        }

        return result
    }

    // MARK: - Counting

    private static func spatialCount(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        // `ShapeSpec` clamps arrangements to nine elements, so the answer must stay in that range.
        let count = MathKit.clamp(Int((3.0 + theta * 1.2).rounded()), 4, 9)
        let target = ShapeSpec(
            shape: generator.pick(ShapeSpec.Shape.allCases.filter { $0 != .ring && $0 != .bar }),
            fill: generator.pick([.solid, .hollow]),
            rotation: generator.pick([0, 45, 90, 135, 180, 225, 270, 315]),
            arrangement: .cluster,
            count: count
        )

        let distractors = GenSupport.distinctValues(
            excluding: count, from: [count + 1, count - 1, count + 2, count - 2, max(1, count - 3)], count: 3
        )
        let labels = ([count] + distractors).map(String.init)
        let choice = GenSupport.choice(labels: labels, correctIndex: 0, prefix: id, generator: &generator)

        return Puzzle(
            id: id,
            kind: .spatialCount,
            theta: MathKit.clamp(theta, 1.5, 4.0),
            prompt: "How many shapes are there?",
            subtitle: "Overlapping counts too",
            stimulus: .shape(target),
            options: choice.options,
            answer: .optionIndex(choice.answerIndex),
            hint: "Sweep left to right, top row first, and count a shape when its centre crosses the middle. Random looking always loses shapes.",
            timeLimit: 20,
            skillTag: "spatial-count"
        )
    }
}
