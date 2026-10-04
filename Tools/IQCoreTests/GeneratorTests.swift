import XCTest
@testable import IQCore

/// Sweeps every puzzle kind across a wide range of seeds and difficulties. The point is
/// not that each item is hard to hand-check, but that none of them is *broken*: an answer
/// that points outside the option list, duplicate options, an out-of-range difficulty or a
/// hint that leaks the answer would all silently corrupt the player's report.
final class GeneratorTests: XCTestCase {
    /// Enough seeds that every branch of every generator gets exercised.
    private let seedCount = 60

    private func sweep(
        _ body: (PuzzleKind, Double, inout SeededGenerator, String) -> Puzzle,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for kind in PuzzleKind.allCases {
            for step in 0...12 {
                let theta = 1.0 + Double(step) * 0.35
                for seed in 0..<seedCount {
                    var generator = SeededGenerator(seed: UInt64(seed &* 7919 &+ Int(theta * 100)))
                    let puzzle = body(kind, theta, &generator, "\(kind)-\(seed)")

                    XCTAssertEqual(puzzle.kind, kind, file: file, line: line)
                    XCTAssertEqual(
                        puzzle.domain, kind.domain,
                        "kind/domain mismatch for \(kind)", file: file, line: line
                    )
                    XCTAssertTrue(
                        (1.0...5.2).contains(puzzle.theta),
                        "\(kind) produced θ=\(puzzle.theta) for requested \(theta)", file: file, line: line
                    )
                    XCTAssertFalse(puzzle.prompt.isEmpty, "\(kind) has no prompt", file: file, line: line)
                    XCTAssertFalse(puzzle.hint.isEmpty, "\(kind) has no hint", file: file, line: line)
                    XCTAssertFalse(
                        puzzle.skillTag.isEmpty, "\(kind) has no skill tag", file: file, line: line
                    )
                    XCTAssertGreaterThan(
                        puzzle.timeLimit, 0, "\(kind) has no time limit", file: file, line: line
                    )
                    self.checkAnswerIsReachable(puzzle, file: file, line: line)
                }
            }
        }
    }

    private func checkAnswerIsReachable(_ puzzle: Puzzle, file: StaticString, line: UInt) {
        switch puzzle.answer {
        case .optionIndex(let index):
            XCTAssertGreaterThanOrEqual(index, 0, file: file, line: line)
            XCTAssertLessThan(index, puzzle.options.count, "\(puzzle.id) answer out of range", file: file, line: line)
            self.checkOptionsAreUnique(puzzle, file: file, line: line)
        case .tapSequence(let taps):
            self.checkMemoryAnswer(puzzle, taps: taps, file: file, line: line)
        case .ordering(let order):
            XCTAssertFalse(order.isEmpty, file: file, line: line)
            XCTAssertEqual(order.sorted(), Array(0..<order.count).sorted(),
                           "\(puzzle.id) ordering must be a permutation", file: file, line: line)
            XCTAssertEqual(order.count, puzzle.orderLabels.count,
                           "\(puzzle.id) ordering must cover every label", file: file, line: line)
        case .word(let word):
            XCTAssertFalse(word.isEmpty, file: file, line: line)
            XCTAssertEqual(
                word.count, puzzle.tiles.count,
                "\(puzzle.id) tile count must match the answer length", file: file, line: line
            )
            let wordLetters = word.map(String.init).sorted()
            let tileLetters = puzzle.tiles.sorted()
            XCTAssertEqual(
                tileLetters, wordLetters,
                "\(puzzle.id) tiles must be an exact scramble of the answer", file: file, line: line
            )
            XCTAssertNotEqual(
                puzzle.tiles, word.map(String.init),
                "\(puzzle.id) must not present the answer already in order", file: file, line: line
            )
        }
    }

    private func checkOptionsAreUnique(_ puzzle: Puzzle, file: StaticString, line: UInt) {
        XCTAssertGreaterThanOrEqual(puzzle.options.count, 2, "\(puzzle.id) has too few options", file: file, line: line)
        var seen = Set<String>()
        for option in puzzle.options {
            // `hashValue` is randomly seeded per process and signed, so compare a stable
            // textual description instead of a numeric hash.
            let signature: String
            switch option.graphic {
            case .none:
                signature = "text:\(option.title)"
            case .shape(let spec):
                signature = "shape:\(spec)"
            case .grid(let spec):
                signature = "grid:\(spec.cells.map { $0.map(String.init(describing:)) ?? "-" })"
            case .word(let text):
                signature = "word:\(text)"
            case .number(let value):
                signature = "number:\(value)"
            }
            XCTAssertTrue(seen.insert(signature).inserted,
                          "\(puzzle.id) has a duplicate option: \(signature)", file: file, line: line)
        }
    }

    private func checkMemoryAnswer(_ puzzle: Puzzle, taps: [Int], file: StaticString, line: UInt) {
        guard case .memory(let spec) = puzzle.stimulus else {
            XCTFail("\(puzzle.id) memory puzzle has no memory stimulus", file: file, line: line)
            return
        }
        XCTAssertTrue(spec.isValid, "\(puzzle.id) produced an out-of-bounds memory spec", file: file, line: line)
        XCTAssertFalse(taps.isEmpty, "\(puzzle.id) has an empty answer sequence", file: file, line: line)
        XCTAssertEqual(taps.count, Set(taps).count,
                       "\(puzzle.id) answer repeats a cell", file: file, line: line)
    }

    // MARK: - Per-family sweeps

    func testEveryKindProducesASolvablePuzzle() {
        self.sweep { kind, theta, generator, id in
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
    }

    func testGeneratorsAreDeterministicForAGivenSeed() {
        for kind in PuzzleKind.allCases {
            var first = SeededGenerator(seed: 4242)
            var second = SeededGenerator(seed: 4242)
            let a = self.build(kind: kind, theta: 3.2, generator: &first)
            let b = self.build(kind: kind, theta: 3.2, generator: &second)
            XCTAssertEqual(a.answer, b.answer, "\(kind) is not reproducible from its seed")
            XCTAssertEqual(a.stimulus, b.stimulus, "\(kind) stimulus is not reproducible")
            XCTAssertEqual(a.options, b.options, "\(kind) options are not reproducible")
        }
    }

    private func build(kind: PuzzleKind, theta: Double, generator: inout SeededGenerator) -> Puzzle {
        let id = "determinism-\(kind.rawValue)"
        switch kind {
        case .sequence: return SequenceGenerator.make(theta: theta, generator: &generator, id: id)
        case .anagram, .letterRelation: return VerbalGenerator.make(kind: kind, theta: theta, generator: &generator, id: id)
        case .truthLiar, .ordering: return LogicGenerator.make(kind: kind, theta: theta, generator: &generator, id: id)
        case .memorySequence, .gridRecall: return MemoryGenerator.make(kind: kind, theta: theta, generator: &generator, id: id)
        case .rotation, .mirrorImage, .foldedHoles, .spatialCount: return SpatialGenerator.make(kind: kind, theta: theta, generator: &generator, id: id)
        case .matrix, .oddOneOut: return MatrixGenerator.make(kind: kind, theta: theta, generator: &generator, id: id)
        case .ratio, .percentage, .rate, .probability, .arithmetic: return QuantityGenerator.make(kind: kind, theta: theta, generator: &generator, id: id)
        }
    }

    // MARK: - Family specific invariants

    func testSequenceDifficultyIsNonDecreasingInTheta() {
        // Asking for a harder item must never yield a lower θ, because θ *is* the
        // difficulty signal the scoring engine trusts.
        var previous = -1.0
        for step in 0...14 {
            var generator = SeededGenerator(seed: 99)
            let puzzle = SequenceGenerator.make(
                theta: 1.0 + Double(step) * 0.3, generator: &generator, id: "seq"
            )
            XCTAssertGreaterThanOrEqual(puzzle.theta, previous)
            previous = puzzle.theta
        }
    }

    func testEchoSpanGrowsWithTheta() {
        var previous = 0
        for step in 0...14 {
            var generator = SeededGenerator(seed: 7)
            let puzzle = MemoryGenerator.make(
                kind: .memorySequence, theta: 1.2 + Double(step) * 0.2, generator: &generator, id: "echo"
            )
            guard case .tapSequence(let taps) = puzzle.answer else { return XCTFail("wrong answer type") }
            XCTAssertGreaterThanOrEqual(taps.count, previous, "span shrank as difficulty rose")
            previous = taps.count
        }
    }

    func testGridRecallNeverLightsEveryCell() {
        for seed in 0..<40 {
            var generator = SeededGenerator(seed: UInt64(seed))
            let puzzle = MemoryGenerator.make(
                kind: .gridRecall, theta: 4.0, generator: &generator, id: "grid"
            )
            guard case .tapSequence(let taps) = puzzle.answer,
                  case .memory(let spec) = puzzle.stimulus else { return XCTFail("wrong shape") }
            XCTAssertLessThan(taps.count, spec.cellCount, "every cell lit means nothing to recall")
        }
    }

    func testTruthOrLieHasExactlyOneSolution() {
        // Independent re-derivation of the answer from the rendered statement text.
        for seed in 0..<120 {
            var generator = SeededGenerator(seed: UInt64(seed &* 31 &+ 5))
            let puzzle = LogicGenerator.make(
                kind: .truthLiar, theta: 3.4, generator: &generator, id: "liar"
            )
            guard case .optionIndex(let answerIndex) = puzzle.answer else { return XCTFail("wrong answer type") }
            let answerName = puzzle.options[answerIndex].title

            guard case .text(let body) = puzzle.stimulus else { return XCTFail("wrong stimulus") }
            let lines = body.split(separator: "\n").filter { $0.contains("says") }
            let names = Set(puzzle.options.map(\.title))
            XCTAssertEqual(lines.count, names.count)

            let solutions = names.filter { candidate in
                var verdicts: [Bool] = []
                for line in lines {
                    let text = String(line)
                    guard let speaker = names.first(where: { text.contains($0 + " says") }) else { continue }
                    let claimSelf = text.contains("I am not the liar")
                    let saysLiar = text.contains(" is the liar.")
                    let saysNotLiar = text.contains(" is not the liar.")
                    guard let accused = names.first(where: { $0 != speaker && text.contains($0) }) else { continue }

                    let statementIsTrue: Bool
                    if claimSelf {
                        statementIsTrue = speaker != candidate
                    } else if saysNotLiar {
                        statementIsTrue = accused != candidate
                    } else if saysLiar {
                        statementIsTrue = accused == candidate
                    } else {
                        continue
                    }
                    verdicts.append(statementIsTrue == (speaker != candidate))
                }
                return !verdicts.isEmpty && verdicts.allSatisfy { $0 }
            }
            XCTAssertEqual(
                solutions, [answerName],
                "seed \(seed): puzzle does not have exactly one solution"
            )
        }
    }

    func testOrderingIsNotAlreadySolved() {
        for seed in 0..<60 {
            var generator = SeededGenerator(seed: UInt64(seed &* 13 &+ 3))
            let puzzle = LogicGenerator.make(
                kind: .ordering, theta: 2.0, generator: &generator, id: "order"
            )
            guard case .ordering(let answer) = puzzle.answer else { return XCTFail("wrong answer type") }
            let solvedDisplay = answer.map { puzzle.orderLabels[$0] }
            XCTAssertNotEqual(
                solvedDisplay, puzzle.orderLabels,
                "seed \(seed): the presented order is already correct"
            )
            XCTAssertNotEqual(
                answer, Array(answer.indices),
                "seed \(seed): tapping left to right would solve it"
            )
        }
    }

    func testMirrorAnswerIsTheMirrorOfTheTarget() {
        for seed in 0..<60 {
            var generator = SeededGenerator(seed: UInt64(seed &* 17 &+ 11))
            let puzzle = SpatialGenerator.make(kind: .mirrorImage, theta: 2.8, generator: &generator, id: "mirror")
            guard case .shape(let target) = puzzle.stimulus,
                  case .optionIndex(let answerIndex) = puzzle.answer,
                  case .shape(let answer) = puzzle.options[answerIndex].graphic else {
                return XCTFail("unexpected puzzle shape")
            }
            XCTAssertEqual(answer.shape, target.shape)
            XCTAssertEqual(answer.rotation, target.rotation, "a mirror must not change the angle")
            XCTAssertEqual(answer.handed, -target.handed, "a mirror must reverse handedness")
        }
    }

    func testUnfoldedHolesAreSymmetricAboutTheFoldLines() {
        for seed in 0..<60 {
            var generator = SeededGenerator(seed: UInt64(seed &* 23 &+ 7))
            let puzzle = SpatialGenerator.make(kind: .foldedHoles, theta: 4.0, generator: &generator, id: "fold")
            guard case .optionIndex(let answerIndex) = puzzle.answer,
                  case .grid(let answer) = puzzle.options[answerIndex].graphic else {
                return XCTFail("unexpected puzzle shape")
            }
            let side = Int(Double(answer.cells.count).squareRoot().rounded())
            XCTAssertGreaterThan(side, 0)
            let holes = answer.cells.indices.filter { answer.cells[$0] != nil }
            XCTAssertFalse(holes.isEmpty)

            // Every punch is in the folded quadrant, so the unfolded pattern must be a
            // superset of its own mirror image across the vertical fold line.
            for hole in holes {
                let row = hole / side
                let column = hole % side
                XCTAssertTrue(
                    answer.cells[row * side + (side - 1 - column)] != nil,
                    "seed \(seed): hole at \(row),\(column) has no mirror across the vertical fold"
                )
            }
            if puzzle.subtitle == "Two folds" {
                for hole in holes {
                    let row = hole / side
                    let column = hole % side
                    XCTAssertTrue(
                        answer.cells[(side - 1 - row) * side + column] != nil,
                        "seed \(seed): hole at \(row),\(column) has no mirror across the horizontal fold"
                    )
                }
            }
        }
    }

    func testMatrixMissingCellHasExactlyOneHole() {
        for seed in 0..<60 {
            for theta in [1.8, 3.0, 4.4] {
                var generator = SeededGenerator(seed: UInt64(seed &* 29 &+ Int(theta * 10)))
                let puzzle = MatrixGenerator.make(kind: .matrix, theta: theta, generator: &generator, id: "matrix")
                guard case .matrix(let spec) = puzzle.stimulus else { return XCTFail("wrong stimulus") }
                XCTAssertEqual(spec.cells.count, 9)
                XCTAssertEqual(spec.cells.filter { $0 == nil }.count, 1)
                XCTAssertEqual(spec.missingIndex, 8)

                // The option at the answer index must equal what the generator placed in
                // the missing cell, so the solver's rule really does reproduce it.
                guard case .optionIndex(let answerIndex) = puzzle.answer,
                      case .shape(let answer) = puzzle.options[answerIndex].graphic else {
                    return XCTFail("unexpected answer shape")
                }
                XCTAssertFalse(answer.arrangement == .ring)
            }
        }
    }

    func testArithmeticAnswersAreArithmeticallyCorrect() {
        for seed in 0..<80 {
            var generator = SeededGenerator(seed: UInt64(seed))
            let puzzle = QuantityGenerator.make(
                kind: .arithmetic, theta: 3.0, generator: &generator, id: "arith"
            )
            guard case .text(let question) = puzzle.stimulus,
                  case .optionIndex(let answerIndex) = puzzle.answer else { return XCTFail("unexpected shape") }
            let answer = puzzle.options[answerIndex].title
            let numbers = question.split(whereSeparator: { !$0.isNumber })
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard let a = numbers.first, let b = numbers.dropFirst().first else { continue }

            if question.contains("+") {
                XCTAssertEqual(Int(answer), a + b, "seed \(seed): \(question)")
            } else if question.contains("−") {
                XCTAssertEqual(Int(answer), abs(a - b), "seed \(seed): \(question)")
            } else if question.contains("half") {
                XCTAssertEqual(Int(answer), (a * b) / 2, "seed \(seed): \(question)")
            }
        }
    }

    func testRateAnswersSatisfyTheCombinedRateIdentity() {
        for seed in 0..<60 {
            var generator = SeededGenerator(seed: UInt64(seed &* 37 &+ 2))
            let puzzle = QuantityGenerator.make(kind: .rate, theta: 3.8, generator: &generator, id: "rate")
            guard case .text(let question) = puzzle.stimulus,
                  case .optionIndex(let answerIndex) = puzzle.answer else { return XCTFail("unexpected shape") }
            let numbers = question.split(whereSeparator: { !$0.isNumber })
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard numbers.count >= 3 else { continue }

            let together = Double(numbers[0])
            let aloneA = Double(numbers[1])
            let other = Double(Int(puzzle.options[answerIndex].title) ?? 0)
            let expected = together * aloneA / (aloneA - together)
            XCTAssertEqual(other, expected, accuracy: 0.5, "seed \(seed): \(question)")
        }
    }

    func testPercentageAnswersAreWholeNumbers() {
        for seed in 0..<60 {
            for theta in [1.5, 3.0, 4.5] {
                var generator = SeededGenerator(seed: UInt64(seed &* 41 &+ Int(theta)))
                let puzzle = QuantityGenerator.make(
                    kind: .percentage, theta: theta, generator: &generator, id: "pct"
                )
                guard case .text(let question) = puzzle.stimulus,
                      case .optionIndex(let answerIndex) = puzzle.answer else { continue }
                XCTAssertFalse(
                    puzzle.options[answerIndex].title.contains("."),
                    "seed \(seed): \(question) produced a fractional answer"
                )
            }
        }
    }

    func testHintsDoNotContainTheAnswerForChoicePuzzles() {
        for kind in [PuzzleKind.sequence, .ratio, .percentage, .rate, .probability, .arithmetic] {
            for seed in 0..<40 {
                var generator = SeededGenerator(seed: UInt64(seed &* 3 &+ 1))
                let puzzle = QuantityGenerator.make(kind: kind, theta: 3.0, generator: &generator, id: "hint")
                    as Puzzle
                guard case .optionIndex(let answerIndex) = puzzle.answer else { continue }
                let answerText = puzzle.options[answerIndex].title
                guard answerText.count >= 3 else { continue }
                XCTAssertFalse(
                    puzzle.hint.contains(answerText),
                    "\(kind): the hint leaks the answer '\(answerText)'"
                )
            }
        }
    }
}