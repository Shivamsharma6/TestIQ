import SwiftUI

/// The four interaction archetypes.
///
/// Everything a puzzle can ask the player to *do* reduces to one of these, which is why
/// nineteen puzzle families need only four interaction views. Adding a puzzle family is a
/// change to a generator, not to the UI.
struct InteractionView: View {
    let puzzle: Puzzle
    let model: GameViewModel
    var accent: Color
    /// Non-nil while feedback is showing, so the correct choice can be revealed.
    var revealedCorrect: Bool

    var body: some View {
        switch self.puzzle.archetype {
        case .choice:
            ChoiceInteraction(puzzle: self.puzzle, model: self.model, accent: self.accent,
                              revealed: self.revealedCorrect)
        case .echo:
            EchoInteraction(puzzle: self.puzzle, model: self.model, accent: self.accent,
                            revealed: self.revealedCorrect)
        case .order:
            OrderInteraction(puzzle: self.puzzle, model: self.model, accent: self.accent,
                             revealed: self.revealedCorrect)
        case .scramble:
            ScrambleInteraction(puzzle: self.puzzle, model: self.model, accent: self.accent,
                                revealed: self.revealedCorrect)
        }
    }
}

// MARK: - Choice

private struct ChoiceInteraction: View {
    let puzzle: Puzzle
    let model: GameViewModel
    let accent: Color
    let revealed: Bool

    private var columns: [GridItem] {
        let count = self.puzzle.options.count
        // Grids wider than four would push tap targets below the 44pt minimum on a phone.
        let columns = count <= 2 ? count : (count <= 4 ? 2 : 3)
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: self.columns, spacing: 10) {
            ForEach(Array(self.puzzle.options.enumerated()), id: \.element.id) { index, option in
                let tile = OptionTile(option: option, state: self.state(for: index),
                                      accent: self.accent, answerNumber: index + 1)
                Button {
                    model.choose(option: index)
                } label: {
                    tile
                }
                .buttonStyle(TileButtonStyle())
                .disabled(model.phase != .awaitingAnswer)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tile.accessibilityLabel)
            }
        }
        .animation(Motion.enabled ? Motion.snappy : nil, value: model.phase)
        .animation(Motion.enabled ? Motion.gentle : nil, value: revealed)
    }

    private func state(for index: Int) -> OptionTile.State {
        let chosen = model.selectedOptionIndex == index
        let isCorrect = model.correctOptionIndex == index
        if chosen {
            return model.lastAnswerCorrect == true ? .correct : .incorrect
        }
        if self.revealed, isCorrect { return .revealed }
        return .idle
    }
}

struct OptionTile: View {
    enum State { case idle, correct, incorrect, revealed, disabled }

    let option: PuzzleOption
    let state: State
    let accent: Color
    let answerNumber: Int

    var body: some View {
        VStack(spacing: 8) {
            switch self.option.graphic {
            case .none:
                Text(self.option.title)
                    .font(.app(.title3, size: 19, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)

            case .number(let value):
                Text(String(value))
                    .font(.mono(22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

            case .word(let text):
                Text(text)
                    .font(.app(.headline, size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

            case .shape(let spec):
                ShapeView(spec: spec, tint: self.accent)
                    .frame(maxHeight: 62)
                    .frame(maxWidth: .infinity)

            case .grid(let spec):
                MatrixGridView(spec: spec, accent: self.accent, isOption: true)
                    .frame(maxHeight: 74)
            }

            if self.hasSupplementaryTitle {
                Text(self.option.title)
                    .font(.app(.caption, size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 78)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(self.background)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(self.border, lineWidth: self.borderWidth)
                }
        }
        .overlay(alignment: .topTrailing) {
            if let symbol = self.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(self.foreground)
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(Motion.enabled ? Motion.snappy : nil, value: self.state)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityAddTraits(self.state == .correct ? [.isButton, .isSelected] : .isButton)
    }

    private var hasSupplementaryTitle: Bool {
        guard !self.option.title.isEmpty else { return false }
        switch self.option.graphic {
        case .number(let value): return self.option.title != String(value)
        case .word(let text): return self.option.title != text
        case .none, .shape, .grid: return false
        }
    }

    private var background: Color {
        switch self.state {
        case .correct: return Theme.correct.opacity(0.18)
        case .incorrect: return Theme.incorrect.opacity(0.18)
        case .revealed: return Theme.correct.opacity(0.12)
        case .idle, .disabled: return Theme.surface
        }
    }

    private var foreground: Color {
        switch self.state {
        case .correct: return Theme.correct
        case .incorrect: return Theme.incorrect
        case .revealed: return Theme.correct
        case .idle, .disabled: return Theme.textSecondary
        }
    }

    private var border: Color {
        switch self.state {
        case .correct: return Theme.correct
        case .incorrect: return Theme.incorrect
        case .revealed: return Theme.correct.opacity(0.6)
        case .idle, .disabled: return Theme.stroke
        }
    }

    private var borderWidth: CGFloat {
        self.state == .idle || self.state == .disabled ? 1 : 2
    }

    private var symbol: String? {
        switch self.state {
        case .correct: return "checkmark.circle.fill"
        case .incorrect: return "xmark.circle.fill"
        case .revealed: return "checkmark.circle.fill"
        case .idle, .disabled: return nil
        }
    }

    var accessibilityLabel: String {
        var base = self.option.title
        if base.isEmpty {
            switch self.option.graphic {
            case .number(let value): base = "Option \(value)"
            case .shape(let spec):
                let displayedCount = spec.arrangement == .single ? 1 : max(1, min(spec.count, 9))
                base = "Answer option \(self.answerNumber): \(displayedCount) \(spec.fill.rawValue) \(spec.shape.rawValue), \(spec.arrangement.rawValue), rotated \(spec.rotation) degrees"
                if spec.handed < 0 { base += ", mirrored" }
            case .grid: base = "Grid option \(self.answerNumber)"
            case .none, .word: base = "Option"
            }
        }
        switch self.state {
        case .correct: return "\(base), correct"
        case .incorrect: return "\(base), incorrect"
        case .revealed: return "\(base), this was the correct answer"
        case .idle, .disabled: return base
        }
    }
}

// MARK: - Echo (memory span + grid recall)

private struct EchoInteraction: View {
    let puzzle: Puzzle
    let model: GameViewModel
    let accent: Color
    let revealed: Bool

    var body: some View {
        VStack(spacing: 16) {
            if case .memory(let spec) = self.puzzle.stimulus {
                MemoryGridView(
                    spec: spec,
                    accent: self.accent,
                    phase: model.memoryPhase,
                    selected: Set(model.tappedIndices),
                    isSequence: model.isEcho,
                    onTap: { model.tap(tile: $0) }
                )
            }

            if model.isGridRecall {
                Text("Tap every tile that lit up, in any order")
                    .font(.app(.footnote, size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }

            if self.revealed {
                VStack(spacing: 6) {
                    Text("The answer was")
                        .font(.app(.caption, size: 12, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                    HStack(spacing: 6) {
                        ForEach(Array((model.expectedOptionIndices ?? []).enumerated()), id: \.offset) { _, index in
                            Text("\(index + 1)")
                                .font(.mono(13, weight: .bold))
                                .foregroundStyle(Theme.correct)
                                .frame(width: 26, height: 26)
                                .background { Circle().fill(Theme.correct.opacity(0.15)) }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(Motion.enabled ? Motion.gentle : nil, value: model.phase)
        .animation(Motion.enabled ? Motion.gentle : nil, value: revealed)
    }
}

extension GameViewModel {
    /// The cells the player should have chosen, for the post-answer reveal.
    var expectedOptionIndices: [Int]? {
        guard case .tapSequence(let taps) = self.puzzle.answer else { return nil }
        return taps
    }
}

// MARK: - Ordering

private struct OrderInteraction: View {
    let puzzle: Puzzle
    let model: GameViewModel
    let accent: Color
    let revealed: Bool

    var body: some View {
        VStack(spacing: 14) {
            if !model.chosenOrder.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your order")
                        .font(.app(.caption, size: 11, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(Theme.textTertiary)

                    HStack(spacing: 6) {
                        ForEach(Array(model.chosenOrder.enumerated()), id: \.offset) { position, index in
                            HStack(spacing: 5) {
                                Text("\(position + 1)")
                                    .font(.mono(10, weight: .black))
                                    .foregroundStyle(Color.black.opacity(0.7))
                                    .frame(width: 16, height: 16)
                                    .background { Circle().fill(self.accent) }
                                Text(puzzle.orderLabels[index])
                                    .font(.app(.subheadline, size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Theme.surfaceRaised)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Your chosen order: " + model.chosenOrder
                    .map { puzzle.orderLabels[$0] }.joined(separator: ", "))
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                spacing: 10
            ) {
                ForEach(Array(puzzle.orderLabels.enumerated()), id: \.offset) { index, label in
                    let position = model.chosenOrder.firstIndex(of: index)
                    Button {
                        model.tapOrder(labelIndex: index)
                    } label: {
                        HStack(spacing: 8) {
                            Text(label)
                                .font(.app(.subheadline, size: 14, weight: .semibold))
                                .foregroundStyle(position == nil ? Theme.textPrimary : Theme.textTertiary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                            Spacer(minLength: 0)
                            if let position {
                                Text("\(position + 1)")
                                    .font(.mono(11, weight: .black))
                                    .foregroundStyle(Color.black.opacity(0.7))
                                    .frame(width: 18, height: 18)
                                    .background { Circle().fill(self.accent) }
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: Theme.Metrics.minTarget)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(position == nil ? Theme.surface : Theme.surfaceRaised)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(
                                            position == nil ? Theme.stroke : self.accent.opacity(0.5),
                                            lineWidth: 1
                                        )
                                }
                        }
                    }
                    .buttonStyle(TileButtonStyle())
                    .disabled(model.phase != .awaitingAnswer)
                    .accessibilityLabel("\(label), tap to add to your order")
                    .accessibilityValue(position.map { "position \($0 + 1)" } ?? "not chosen")
                }
            }
            .animation(Motion.enabled ? Motion.snappy : nil, value: model.chosenOrder)
        }
    }
}

// MARK: - Scramble (anagram)

private struct ScrambleInteraction: View {
    let puzzle: Puzzle
    let model: GameViewModel
    let accent: Color
    let revealed: Bool

    var body: some View {
        VStack(spacing: 18) {
            // The answer being built, with the letters that have been consumed greyed out
            // in the bank below so the player can always see what is left.
            HStack(spacing: 6) {
                ForEach(0..<puzzle.tiles.count, id: \.self) { slot in
                    Text(slot < model.submittedLetters.count ? model.submittedLetters[slot] : "")
                        .font(.app(.title2, size: 22, weight: .bold))
                        .foregroundStyle(
                            slot < model.submittedLetters.count
                                ? (self.revealed ? Theme.incorrect : Theme.textPrimary)
                                : Theme.textTertiary.opacity(0.4)
                        )
                        .frame(width: 34, height: 44)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Theme.surface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(
                                            slot < model.submittedLetters.count ? self.accent.opacity(0.5) : Theme.stroke,
                                            lineWidth: 1
                                        )
                                }
                        }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your word so far: " + model.submittedLetters.joined())

            if self.revealed, let expected = model.expectedWord {
                Text("The word was “\(expected)”")
                    .font(.app(.subheadline, size: 14, weight: .semibold))
                    .foregroundStyle(Theme.correct)
                    .transition(.opacity)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                spacing: 8
            ) {
                ForEach(Array(puzzle.tiles.enumerated()), id: \.offset) { index, letter in
                    let used = model.usedTileIndices.contains(index)
                    Button {
                        model.tapTile(index)
                    } label: {
                        Text(letter)
                            .font(.app(.title3, size: 20, weight: .bold))
                            .foregroundStyle(used ? Theme.textTertiary.opacity(0.3) : Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: Theme.Metrics.minTarget + 6)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(used ? Theme.surface.opacity(0.5) : Theme.surfaceRaised)
                            }
                    }
                    .buttonStyle(TileButtonStyle())
                    .disabled(used || model.phase != .awaitingAnswer)
                    .accessibilityLabel("Letter \(letter)")
                    .accessibilityValue(used ? "used" : "available")
                }
            }
        }
        .animation(Motion.enabled ? Motion.snappy : nil, value: model.submittedLetters)
    }
}

// MARK: - Shared

/// Press feedback used by every tile, so tapping feels the same everywhere.
struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && Motion.enabled ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Motion.enabled ? Motion.snappy : nil, value: configuration.isPressed)
    }
}
