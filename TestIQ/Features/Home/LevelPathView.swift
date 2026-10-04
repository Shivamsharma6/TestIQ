import SwiftUI

/// The ascent path.
///
/// Levels run bottom to top, so the whole progression reads the way climbing does. The path
/// meanders so neighbouring nodes are visually distinct without needing connector
/// geometry, and the next available node pulses to draw the eye.
struct LevelPathView: View {
    let progress: PlayerProgress
    let onSelect: (Int) -> Void

    private var nodes: [(level: LevelDefinition, isNext: Bool)] {
        LevelCatalog.all.map { level in
            (level, isNext: self.progress.isUnlocked(level.id) && !self.progress.isCleared(level.id))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(self.nodes.reversed().enumerated()), id: \.element.level.id) { position, node in
                let row = position / 2
                let isLeft = position.isMultiple(of: 2)

                HStack {
                    if isLeft {
                        LevelNodeView(
                            level: node.level,
                            stars: self.progress.stars(for: node.level.id),
                            isUnlocked: self.progress.isUnlocked(node.level.id),
                            isCleared: self.progress.isCleared(node.level.id),
                            isNext: node.isNext,
                            attempts: self.progress.attempts(for: node.level.id)
                        ) {
                            self.onSelect(node.level.id)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer().frame(maxWidth: 18)

                    if !isLeft {
                        LevelNodeView(
                            level: node.level,
                            stars: self.progress.stars(for: node.level.id),
                            isUnlocked: self.progress.isUnlocked(node.level.id),
                            isCleared: self.progress.isCleared(node.level.id),
                            isNext: node.isNext,
                            attempts: self.progress.attempts(for: node.level.id)
                        ) {
                            self.onSelect(node.level.id)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.horizontal, row.isMultiple(of: 2) ? 26 : 46)
                .padding(.vertical, 12)
                .id(node.level.id)
            }
        }
    }
}

struct LevelNodeView: View {
    let level: LevelDefinition
    let stars: Int
    let isUnlocked: Bool
    let isCleared: Bool
    let isNext: Bool
    var attempts: Int = 1
    let action: () -> Void

    @State private var pulse = false

    private var accent: Color { Theme.accent(named: self.level.accentName) }

    var body: some View {
        Button {
            guard self.isUnlocked else { return }
            HapticsEngine.shared.tap()
            self.action()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(self.isUnlocked ? self.accent.opacity(0.16) : Color.white.opacity(0.04))
                        .frame(width: 68, height: 68)

                    Circle()
                        .strokeBorder(
                            self.isUnlocked ? self.accent : Color.white.opacity(0.12),
                            lineWidth: self.isNext ? 2.5 : 1.5
                        )
                        .frame(width: 68, height: 68)
                        .scaleEffect(self.pulse && Motion.enabled ? 1.13 : 1)
                        .opacity(self.pulse && Motion.enabled ? 0 : 1)

                    Group {
                        if self.isUnlocked {
                            VStack(spacing: 0) {
                                Text("\(self.level.id)")
                                    .font(.mono(24, weight: .heavy))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(self.level.domain.shortTitle.uppercased())
                                    .font(.app(.caption2, size: 8, weight: .heavy))
                                    .tracking(0.8)
                                    .foregroundStyle(self.accent)
                            }
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }

                Text(self.level.name)
                    .font(.app(.footnote, size: 13, weight: .bold))
                    .foregroundStyle(self.isUnlocked ? Theme.textPrimary : Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if self.stars > 0 {
                    StarRating(stars: self.stars, size: 10)
                } else if self.isNext {
                    Text("Tap to start")
                        .font(.app(.caption2, size: 10, weight: .semibold))
                        .foregroundStyle(self.accent)
                } else if !self.isUnlocked {
                    Text("Floor \(self.level.id - 1) first")
                        .font(.app(.caption2, size: 10, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    Text("Attempt \(self.attempts)")
                        .font(.app(.caption2, size: 10, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(maxWidth: 120)
            .contentShape(Rectangle())
        }
        .buttonStyle(TileButtonStyle())
        .disabled(!self.isUnlocked)
        .onAppear {
            guard self.isNext, Motion.enabled else { return }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                self.pulse = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Floor \(self.level.id), \(self.level.name)")
        .accessibilityValue(self.accessibilityValue)
        .accessibilityHint(self.isUnlocked ? "Double tap to play" : "Locked. Clear floor \(self.level.id - 1) first.")
        .accessibilityAddTraits(self.isNext ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityValue: String {
        guard self.isUnlocked else { return "Locked" }
        if self.stars > 0 { return "\(self.stars) of 3 stars, cleared" }
        return self.isNext ? "Next floor, not yet attempted" : "Not yet cleared"
    }
}