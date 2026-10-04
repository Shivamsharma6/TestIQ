import Foundation

/// Word-based reasoning: rebuilding scrambled words, letter-algebra, and property-based
/// odd-one-out.
enum VerbalGenerator {
    static func make(kind: PuzzleKind, theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        switch kind {
        case .anagram: return self.anagram(theta: theta, generator: &generator, id: id)
        case .letterRelation: return self.letterRelation(theta: theta, generator: &generator, id: id)
        default: return self.wordOddOneOut(theta: theta, generator: &generator, id: id)
        }
    }

    // MARK: - Anagram

    private static func anagram(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let minLength = Int(theta) >= 4 ? 7 : (Int(theta) >= 3 ? 6 : 5)
        let pool = GenSupport.commonWords.filter { $0.count >= minLength }
        let word = generator.pick(pool.isEmpty ? GenSupport.commonWords : pool)
        let shuffled: [String] = generator.shuffled(word.map(String.init))
        // A scramble identical to the original would give the answer away for free.
        let tiles: [String] = shuffled.joined() == word ? self.rotate(word).map(String.init) : shuffled

        let thetaValue = MathKit.clamp(theta, 1.0, 4.4)
        return Puzzle(
            id: id,
            kind: .anagram,
            theta: thetaValue,
            prompt: "Rebuild the word",
            subtitle: "\(word.count) letters, one tap each",
            stimulus: .none,
            options: [],
            answer: .word(word),
            hint: self.scrambleHint(for: word),
            timeLimit: MathKit.clamp(28.0 - thetaValue * 3.0, 14, 28),
            skillTag: "anagram-scramble",
            tiles: tiles
        )
    }

    private static func scrambleHint(for word: String) -> String {
        let vowels = word.filter { "aeiou".contains($0) }.count
        return "It starts with '\(word.first.map(String.init) ?? "")' and contains \(vowels) vowel\(vowels == 1 ? "" : "s")."
    }

    private static func rotate(_ word: String) -> String {
        guard word.count > 1 else { return word }
        let characters = word.map(String.init)
        return (characters[1...] + [characters[0]]).joined()
    }

    // MARK: - Letter algebra

    private static func letterRelation(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let shift = theta < 2.4
            ? generator.pick([3, 4, 5])
            : (theta < 3.6 ? generator.pick([7, 9, 11]) : generator.pick([13, 15, 19]))

        let target = generator.nextInt(in: 2...20)
        let source = (target - shift) % 26
        // Redraw only the random choices; the requested θ must survive the retry or the
        // floor's difficulty ramp would develop a dip.
        guard source >= 0, source != target else {
            return self.letterRelation(theta: theta, generator: &generator, id: id)
        }

        let sourceLetter = Self.letter(source)
        let targetLetter = Self.letter(target)
        let clueStart = generator.nextInt(in: 0...(25 - max(source, target)))
        let clueEnd = clueStart + generator.nextInt(in: 3...8)
        let clueLetters = (clueStart...clueEnd)
            .filter { $0 != source && $0 != target }
            .map(Self.letter)

        let clue = clueLetters.map { letter -> String in
            let position = Self.alphabetIndex(of: letter) ?? 0
            return letter + " + " + String(shift) + " = " + Self.letter(position + shift)
        }.joined(separator: ", ")

        let stem = "Add " + String(shift) + " to a letter's alphabet position. "
            + sourceLetter + " + " + String(shift) + " = " + targetLetter + "."
            + (clueLetters.isEmpty ? "" : " Also: " + clue + ".")

        let answerLetter = Self.letter(target)
        let rawCandidates = [
            Self.letter((target + 2) % 26),
            Self.letter((target + shift) % 26),
            Self.letter((target - shift + 26) % 26),
            Self.letter((target + 1) % 26),
            Self.letter((target + 25) % 26),
        ]
        var distractors: [String] = []
        for candidate in rawCandidates where candidate != answerLetter && !distractors.contains(candidate) {
            distractors.append(candidate)
            if distractors.count == 3 { break }
        }
        let labels = [answerLetter] + distractors
        let choice = GenSupport.choice(labels: labels, correctIndex: 0, prefix: id, generator: &generator)

        let hard = theta >= 3.6
        return Puzzle(
            id: id,
            kind: .letterRelation,
            theta: MathKit.clamp(theta, 1.0, 4.4),
            prompt: hard ? "Which letter follows the rule?" : "Complete the letter rule",
            subtitle: "A = 1, B = 2, … Z = 26",
            stimulus: .text(stem),
            options: choice.options,
            answer: .optionIndex(choice.answerIndex),
            hint: "Convert the letter you are given into a number, add \(shift), then convert back.",
            timeLimit: 24,
            skillTag: "letter-shift"
        )
    }

    /// Nonisolated so this compiles identically in the app target (which defaults to
    /// MainActor isolation) and in the SwiftPM test build (which does not).
    nonisolated private static func letter(_ index: Int) -> String {
        let normalised = ((index % 26) + 26) % 26
        return String(UnicodeScalar(UInt8(65 + normalised)))
    }

    nonisolated private static func alphabetIndex(of letter: String) -> Int? {
        guard let scalar = letter.uppercased().unicodeScalars.first else { return nil }
        return Int(scalar.value) - 65
    }

    // MARK: - Word odd-one-out

    private static func wordOddOneOut(theta: Double, generator: inout SeededGenerator, id: String) -> Puzzle {
        let eligible = GenSupport.wordPropertyGroups.filter { $0.words.count >= 4 }
        let group = generator.pick(eligible)
        let oddCount = theta < 2.4 ? 4 : 5
        let members = generator.sample(group.words, count: oddCount - 1)
        let oddWord = self.outsider(near: group.name, generator: &generator)

        let words = generator.shuffled(members + [oddWord])
        let thetaValue = MathKit.clamp(theta, 1.0, 4.4)

        return Puzzle(
            id: id,
            kind: .oddOneOut,
            theta: thetaValue,
            prompt: "Which word does not belong?",
            subtitle: "Exactly one answer",
            stimulus: .none,
            options: words.map { PuzzleOption(id: "\(id)-\($0)", title: $0, graphic: .word($0)) },
            answer: .optionIndex(words.firstIndex(of: oddWord) ?? 0),
            hint: "Take each word in turn and state a property out loud. The one that breaks the shared property is the answer.",
            timeLimit: MathKit.clamp(26.0 - thetaValue * 2.5, 12, 26),
            skillTag: "word-property"
        )
    }

    /// A word drawn from a *different* property group, so the odd one out is genuinely
    /// off-pattern rather than accidentally sharing the rule.
    private static func outsider(near name: String, generator: inout SeededGenerator) -> String {
        let others = GenSupport.wordPropertyGroups.filter { $0.name != name }
        return generator.pick(generator.pick(others).words)
    }
}