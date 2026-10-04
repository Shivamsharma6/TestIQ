import Foundation

/// Shared plumbing for the generators: distractor construction and option shuffling.
///
/// Every generator must produce a *plausible* wrong answer. A distractor that is obviously
/// wrong teaches the player nothing and inflates their score; a distractor that is a real
/// misreading of the rule is what makes the puzzle measure something.
enum GenSupport {
    /// Picks `count` values from `candidates` that are not equal to `answer`, topping up
    /// with small perturbations of the answer if the candidate pool runs dry.
    static func distinctValues(excluding answer: Int, from candidates: [Int], count: Int) -> [Int] {
        var seen = Set<Int>()
        var result: [Int] = []

        for candidate in candidates where candidate != answer && !seen.contains(candidate) {
            seen.insert(candidate)
            result.append(candidate)
            if result.count == count { return result }
        }

        var offset = 1
        while result.count < count && offset < 200 {
            for candidate in [answer - offset, answer + offset] where candidate != answer && !seen.contains(candidate) {
                seen.insert(candidate)
                result.append(candidate)
                if result.count == count { return result }
            }
            offset += 1
        }
        return result
    }

    /// Shuffles the option slots and reports where the correct answer landed.
    ///
    /// Randomising position on every play matters: without it, the correct answer is
    /// always the same button and players learn the button, not the puzzle.
    static func choice(
        labels: [String],
        graphics: [PuzzleOption.Graphic]? = nil,
        correctIndex: Int,
        prefix: String,
        generator: inout SeededGenerator
    ) -> (options: [PuzzleOption], answerIndex: Int) {
        let order = generator.shuffled(Array(labels.indices))
        var options: [PuzzleOption] = []
        var answerIndex = 0
        for (position, originalIndex) in order.enumerated() {
            options.append(
                PuzzleOption(
                    id: "\(prefix)-\(position)",
                    title: labels[originalIndex],
                    graphic: graphics?[originalIndex] ?? .none
                )
            )
            if originalIndex == correctIndex { answerIndex = position }
        }
        return (options, answerIndex)
    }

    /// Builds `shape` options from specs, shuffling them and locating the correct one.
    static func shapeChoice(
        _ specs: [ShapeSpec],
        correctIndex: Int,
        prefix: String,
        generator: inout SeededGenerator
    ) -> (options: [PuzzleOption], answerIndex: Int) {
        self.choice(
            labels: specs.map { _ in "" },
            graphics: specs.map { .shape($0) },
            correctIndex: correctIndex,
            prefix: prefix,
            generator: &generator
        )
    }

    /// Variant of `shapeChoice` for options that are whole grids rather than one shape,
    /// used by the paper-unfolding items.
    static func matrixChoice(
        _ specs: [MatrixSpec],
        correctIndex: Int,
        prefix: String,
        generator: inout SeededGenerator
    ) -> (options: [PuzzleOption], answerIndex: Int) {
        let order = generator.shuffled(Array(specs.indices))
        var options: [PuzzleOption] = []
        var answerIndex = 0
        for (position, originalIndex) in order.enumerated() {
            options.append(
                PuzzleOption(id: "\(prefix)-\(position)", title: "", graphic: .grid(specs[originalIndex]))
            )
            if originalIndex == correctIndex { answerIndex = position }
        }
        return (options, answerIndex)
    }

    /// Builds `total` distinct shapes that include `answer`, drawing from `candidates`
    /// first and then synthesising fill/rotation variants.
    ///
    /// Uniqueness is not cosmetic: two identical option shapes mean one choice is
    /// unfillable, which would silently cost the player the item no matter what they
    /// answer. The synthesised fallback guarantees the count even when the candidates
    /// collide (which happens whenever a rotation step and its complement coincide).
    static func uniqueShapes(answer: ShapeSpec, candidates: [ShapeSpec], total: Int) -> [ShapeSpec] {
        var seen: Set<ShapeSpec> = [answer]
        var result: [ShapeSpec] = [answer]

        for candidate in candidates where result.count < total {
            if seen.insert(candidate).inserted { result.append(candidate) }
        }

        let shapes = ShapeSpec.Shape.allCases
        let fills = ShapeSpec.Fill.allCases
        var index = 0
        while result.count < total && index < 600 {
            let candidate = ShapeSpec(
                shape: shapes[index % shapes.count],
                fill: fills[(index / shapes.count) % fills.count],
                rotation: (index * 45) % 360,
                arrangement: .single
            )
            index += 1
            if seen.insert(candidate).inserted { result.append(candidate) }
        }
        return result
    }

    /// Wraps a label in a word-tile graphic so verbal options look the same everywhere.
    static func wordOption(_ text: String, id: String) -> PuzzleOption {
        PuzzleOption(id: id, title: text, graphic: .word(text))
    }

    /// Word bank for anagram and odd-one-out puzzles. Chosen to be common, unambiguous and
    /// free of letters that are easy to confuse when scrambled.
    static let commonWords: [String] = [
        "listen", "silent", "enlist", "inlet",
        "dormitory", "dirty", "teacher", "student",
        "triangle", "integral", "ration", "trainee",
        "observe", "reserve", "reverse", "verse",
        "master", "stream", "tamer", "merit",
        "planet", "platen", "tangle", "angle",
        "careful", "frail", "farcical", "circle",
        "gallery", "largely", "regally", "gravely",
        "protein", "pointer", "pointe", "triceps",
        "medieval", "received", "decibel", "eleven",
        "candidates", "identical", "cascade", "accident",
        "dilated", "detail", "tailored", "located",
        "granite", "grain", "gaining", "anagram",
        "trace", "cater", "react", "crate",
        "stale", "tastes", "estate", "state",
        "angel", "glean", "angle", "galleon",
    ]

    /// Words grouped by a shared, checkable property — the basis of word odd-one-outs.
    static let wordPropertyGroups: [(name: String, words: [String])] = [
        ("has a silent letter", ["knife", "hour", "psychic", "wrist", "plumb"]),
        ("contains a doubled letter", ["letter", "coffee", "summit", "balloon", "seeing"]),
        ("has no repeated letter", ["brick", "storm", "flute", "quick", "jumpy"]),
        ("is a body of water", ["ocean", "river", "lagoon", "stream", "puddle"]),
        ("is a unit of time", ["second", "minute", "hour", "week", "moment"]),
        ("is a colour", ["crimson", "indigo", "scarlet", "amber", "olive"]),
        ("starts and ends with the same letter", ["radar", "level", "civic", "refer", "rotor"]),
        ("is a kind of animal", ["otter", "lemur", "ibex", "tapir", "gecko"]),
        ("is a tool", ["hammer", "chisel", "mallet", "spanner", "plane"]),
        ("is a fruit", ["apricot", "nectarine", "loquat", "papaya", "satsuma"]),
        ("is a place", ["istanbul", "lisbon", "cairo", "oslo", "quito"]),
        ("is a musical instrument", ["violin", "cello", "banjo", "oboe", "tuba"]),
    ]
}