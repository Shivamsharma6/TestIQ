import SwiftUI

/// The working-memory grid.
///
/// Three presentation phases, and the transition between them *is* the puzzle: the tiles
/// light up, they go dark, and the player has to reproduce what they saw. The timing is
/// deliberately shown as a shrinking bar so the player is never surprised by the window
/// closing.
struct MemoryGridView: View {
    enum Phase: Equatable {
        /// Tiles lighting up one after another, for an echo item.
        case presenting(step: Int, total: Int)
        /// Every target lit simultaneously, for a grid item.
        case presentingAll
        case collecting
        case finished

        var isPresenting: Bool {
            switch self {
            case .presenting, .presentingAll: return true
            case .collecting, .finished: return false
            }
        }
    }

    let spec: MemorySpec
    var accent: Color = Theme.accent
    let phase: Phase
    var selected: Set<Int> = []
    var isSequence: Bool = false
    var onTap: ((Int) -> Void)?

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: max(1, spec.columns))
    }

    var body: some View {
        VStack(spacing: 14) {
            if case .presenting(let step, let total) = self.phase, total > 0 {
                HStack(spacing: 6) {
                    ForEach(0..<max(total, 1), id: \.self) { index in
                        Capsule()
                            .fill(index < step ? self.accent : Color.white.opacity(0.14))
                            .frame(height: 4)
                    }
                }
                .frame(maxWidth: 240)
                .transition(.opacity)
                .accessibilityLabel("Flashing step \(min(step + 1, total)) of \(total)")
            }

            LazyVGrid(columns: self.columns, spacing: 8) {
                ForEach(0..<self.spec.cellCount, id: \.self) { index in
                    tile(at: index)
                }
            }
            .animation(Motion.enabled ? Motion.snappy : nil, value: self.phase)
            .animation(Motion.enabled ? Motion.snappy : nil, value: self.selected)
        }
    }

    @ViewBuilder
    private func tile(at index: Int) -> some View {
        let isLit = self.isLit(index)
        let isSelected = self.selected.contains(index)

        Button {
            self.onTap?(index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isLit ? self.accent : (isSelected ? self.accent.opacity(0.28) : Theme.surfaceRaised))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isSelected ? self.accent : Theme.stroke, lineWidth: isSelected ? 2 : 1)
                    }

                if isLit {
                    Image(systemName: self.isSequence ? "bolt.fill" : "circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.7))
                } else {
                    Text("\(index + 1)")
                        .font(.mono(16, weight: .semibold))
                        .foregroundStyle(isSelected ? self.accent : Theme.textTertiary)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(Motion.enabled && isLit ? 1.03 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(self.phase != .collecting)
        .accessibilityLabel("Tile \(index + 1)")
        .accessibilityValue(isLit ? "lit" : (isSelected ? "selected" : "not selected"))
        .accessibilityHint("Double tap to select")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private func isLit(_ index: Int) -> Bool {
        guard self.phase.isPresenting else { return false }
        if self.isSequence {
            guard case .presenting(let step, _) = self.phase, step >= 0 else { return false }
            return step < self.spec.sequence.count && self.spec.sequence[step] == index
        }
        return self.spec.lit.contains(index)
    }
}

extension MemoryGridView.Phase {
    static let idle: MemoryGridView.Phase = .collecting
}
