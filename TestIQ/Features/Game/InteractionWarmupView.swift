import SwiftUI

/// A small, untimed rehearsal before the first puzzle using each input style.
struct InteractionWarmupView: View {
    let lesson: PuzzleInteraction.Lesson
    let accent: Color
    let onContinue: () -> Void

    @State private var selections: [Int] = []
    @State private var remembering = true
    @State private var complete = false
    @State private var retry = false

    private var isMemory: Bool { lesson == .memorySequence || lesson == .gridRecall }
    private var target: [Int] {
        switch lesson {
        case .choice: return [1]
        case .memorySequence: return [0, 2, 0]
        case .gridRecall: return [0, 3]
        case .order: return [1, 2, 0]
        case .wordTiles: return [1, 0, 2]
        }
    }
    private var title: String {
        switch lesson {
        case .choice: return "Pick it. Lock it."
        case .memorySequence: return "Catch the echo."
        case .gridRecall: return "Spot it. Remember it."
        case .order: return "Build the order."
        case .wordTiles: return "Make the word."
        }
    }
    private var instruction: String {
        if complete { return "You’ve got the controls. Ready for points?" }
        if retry { return "Quick reset. Give that move another try." }
        switch lesson {
        case .choice: return "Tap the answer to 2 + 2. One tap locks it in."
        case .memorySequence:
            return remembering ? "Remember 1 → 3 → 1. A tile can repeat." : "Tap those three tiles in the same order."
        case .gridRecall:
            return remembering ? "Remember the two marked tiles." : "Tap both remembered tiles. Any order works."
        case .order: return "Tap 1, then 2, then 3. The last tap locks it in."
        case .wordTiles: return "Build CAT. Tap letters in order; Undo takes one back."
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack(spacing: 7) {
                    Image(systemName: "gamecontroller.fill")
                    Text("QUICK WARM-UP")
                        .tracking(1.5)
                }
                .font(.app(.caption, size: 12, weight: .heavy))
                .foregroundStyle(accent)

                VStack(spacing: 10) {
                    Text(complete ? "Move mastered." : title)
                        .font(.app(.largeTitle, size: 30, weight: .black))
                        .foregroundStyle(Theme.textPrimary)
                    Text(instruction)
                        .font(.app(.body, size: 16, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)

                Label("No timer · No points at stake", systemImage: "pause.circle")
                    .font(.app(.footnote, size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)

                if complete {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 62, weight: .bold))
                        .foregroundStyle(Theme.correct)
                        .padding(.vertical, 22)
                        .accessibilityLabel("Practice complete")
                    PrimaryButton(title: "Let’s play", systemImage: "bolt.fill", action: onContinue)
                } else {
                    practice
                    if isMemory && remembering {
                        PrimaryButton(title: "Got it — my turn", systemImage: "hand.tap.fill") {
                            remembering = false
                        }
                    } else if !selections.isEmpty && !isMemory {
                        QuietButton(title: "Undo", systemImage: "arrow.uturn.backward") {
                            selections.removeLast()
                        }
                    }
                    QuietButton(title: "Skip warm-up", systemImage: "forward.end", action: onContinue)
                }
            }
            .padding(Theme.Metrics.gutter)
            .padding(.top, 28)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private var practice: some View {
        if isMemory {
            if lesson == .memorySequence && remembering {
                Text("1  →  3  →  1")
                    .font(.mono(28, weight: .bold))
                    .foregroundStyle(accent)
                    .accessibilityLabel("Tile 1, then tile 3, then tile 1")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    let marked = lesson == .gridRecall && remembering && target.contains(index)
                    practiceButton(index, title: "\(index + 1)", marked: marked)
                        .disabled(remembering)
                }
            }
            if !remembering {
                Text("\(selections.count) / \(target.count) taps")
                    .font(.mono(14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityLabel("\(selections.count) of \(target.count) taps entered")
            }
        } else {
            if lesson == .wordTiles {
                Text(selections.map { ["A", "C", "T"][$0] }.joined(separator: " ").padding(toLength: 5, withPad: "_ ", startingAt: 0))
                    .font(.mono(30, weight: .bold))
                    .foregroundStyle(accent)
                    .accessibilityLabel("Word so far: " + selections.map { ["A", "C", "T"][$0] }.joined())
            }
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    practiceButton(index, title: labels[index])
                        .disabled(lesson != .choice && selections.contains(index))
                }
            }
        }
    }

    private var labels: [String] {
        switch lesson {
        case .choice: return ["3", "4", "5"]
        case .order: return ["3", "1", "2"]
        case .wordTiles: return ["A", "C", "T"]
        default: return []
        }
    }

    private func practiceButton(_ index: Int, title: String, marked: Bool = false) -> some View {
        Button { select(index) } label: {
            VStack(spacing: 5) {
                Text(title).font(.mono(25, weight: .bold))
                if marked {
                    Image(systemName: "circle.fill").font(.system(size: 10))
                } else if selections.contains(index) {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(marked ? Color.black : Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 80)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(marked ? accent : Theme.surfaceRaised)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(selections.contains(index) ? accent : Theme.stroke, lineWidth: 2)
                    }
            }
        }
        .buttonStyle(TileButtonStyle())
        .accessibilityLabel(isMemory ? "Tile \(title)" : title)
        .accessibilityValue(marked ? "remember this tile" : selections.contains(index) ? "selected" : "available")
    }

    private func select(_ index: Int) {
        retry = false
        HapticsEngine.shared.tick()
        SoundEngine.shared.selection()
        if lesson == .gridRecall {
            let tap = PuzzleInteraction.memoryTap(index, current: selections, expected: target, gridRecall: true)
            selections = tap.indices
            guard tap.shouldSubmit else { return }
            complete = PuzzleInteraction.memoryMatches(selections, expected: target, gridRecall: true)
        } else {
            selections.append(index)
            if selections != Array(target.prefix(selections.count)) {
                selections = []
                retry = true
                return
            }
            complete = selections.count == target.count
            if !complete { return }
        }
        if complete {
            HapticsEngine.shared.success()
        } else {
            selections = []
            retry = true
        }
    }
}
