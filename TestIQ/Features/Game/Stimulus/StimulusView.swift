import SwiftUI

/// Renders whatever `PuzzleStimulus` a puzzle carries.
///
/// The view layer never inspects `PuzzleKind` to decide what to draw — it only knows how to
/// draw a stimulus. Adding a puzzle family therefore never requires touching this file.
struct StimulusView: View {
    let stimulus: PuzzleStimulus
    var accent: Color = Theme.accent
    var memoryPhase: MemoryGridView.Phase = .collecting

    var body: some View {
        switch self.stimulus {
        case .none:
            EmptyView()

        case .text(let text):
            Text(text)
                .font(.app(.body, size: 17, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(.vertical, 4)
                .fixedSize(horizontal: false, vertical: true)

        case .numbers(let numbers):
            NumberRunView(numbers: numbers, accent: self.accent)

        case .word(let word):
            Text(word)
                .font(.app(.title, size: 34, weight: .bold))
                .foregroundStyle(self.accent)
                .frame(maxWidth: .infinity)

        case .shape(let spec):
            ShapeView(spec: spec, tint: self.accent)
                .frame(maxWidth: 168, maxHeight: 168)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

        case .shapes(let specs):
            HStack(spacing: 10) {
                ForEach(Array(specs.enumerated()), id: \.offset) { _, spec in
                    ShapeView(spec: spec, tint: self.accent).frame(width: 44, height: 44)
                }
            }
            .frame(maxWidth: .infinity)

        case .matrix(let spec):
            MatrixGridView(spec: spec, accent: self.accent)

        case .memory(let spec):
            MemoryGridView(spec: spec, accent: self.accent, phase: self.memoryPhase)
        }
    }
}

/// A run of numbers with a trailing placeholder that invites the next term.
private struct NumberRunView: View {
    let numbers: [Int]
    let accent: Color

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(Array(self.numbers.enumerated()), id: \.offset) { index, value in
                    Text(String(value))
                        .font(.mono(24, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(minWidth: 40, minHeight: 44)
                        .padding(.horizontal, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Theme.surfaceRaised)
                        }
                        .accessibilityLabel("Term \(index + 1), \(value)")
                }
                Image(systemName: "questionmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(self.accent)
                    .frame(width: 44, height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(self.accent.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    .accessibilityLabel("The missing term")
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }
}

/// A square grid of cells, some of them empty (the missing cell) and some filled.
struct MatrixGridView: View {
    let spec: MatrixSpec
    var accent: Color = Theme.accent
    /// Set when this grid is an answer option rather than the puzzle's stimulus.
    var isOption: Bool = false
    var revealedCells: Set<Int>?

    private var side: Int {
        max(1, Int(Double(spec.cells.count).squareRoot().rounded()))
    }

    var body: some View {
        let side = self.side
        Grid(horizontalSpacing: 5, verticalSpacing: 5) {
            ForEach(0..<side, id: \.self) { row in
                GridRow {
                    ForEach(0..<side, id: \.self) { column in
                        let index = row * side + column
                        cell(at: index)
                    }
                }
            }
        }
        .frame(maxWidth: self.isOption ? 120 : 250)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(side) by \(side) grid"
                + (self.spec.cells.contains(where: { $0 == nil }) ? " with a missing cell" : "")
        )
    }

    @ViewBuilder
    private func cell(at index: Int) -> some View {
        let value = index < self.spec.cells.count ? self.spec.cells[index] : nil

        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(value == nil ? Color.white.opacity(0.04) : Theme.surfaceRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            value == nil ? self.accent.opacity(0.55) : Theme.stroke,
                            style: StrokeStyle(lineWidth: 1, dash: value == nil ? [3, 3] : [])
                        )
                }

            if let value {
                ShapeView(spec: value, tint: self.accent)
                    .padding(5)
            } else {
                Image(systemName: "questionmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(self.accent)
            }

            if let revealedCells, revealedCells.contains(index), value != nil {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.correct, lineWidth: 2)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}