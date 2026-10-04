import SwiftUI

/// Quiet atmosphere behind the high-contrast play surfaces. No moving background.
struct ArcadeBackdrop: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.background
            RadialGradient(
                colors: [Theme.violet.opacity(0.16), .clear],
                center: .topTrailing, startRadius: 0, endRadius: 430
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct ArcadeEyebrow: View {
    let text: String
    var tint: Color = Theme.lime

    var body: some View {
        Text(self.text.uppercased())
            .font(.system(.caption2, design: .rounded, weight: .heavy))
            .tracking(1.6)
            .foregroundStyle(self.tint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ArcadeFloorEmblem: View {
    let symbol: String
    var tint: Color = Theme.lime
    var size: CGFloat = 76

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: self.size * 0.30, style: .continuous)
                .fill(self.tint.opacity(0.12))
                .rotationEffect(.degrees(-9))
            RoundedRectangle(cornerRadius: self.size * 0.28, style: .continuous)
                .strokeBorder(self.tint.opacity(0.35), lineWidth: 1)
            Image(systemName: self.symbol)
                .font(.system(size: self.size * 0.38, weight: .bold))
                .foregroundStyle(self.tint)
        }
        .frame(width: self.size, height: self.size)
        .accessibilityHidden(true)
    }
}

/// A short, finite record celebration; reduced motion leaves the record badge visible.
struct ArcadeRecordCelebration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()
    @State private var finished = false

    var body: some View {
        if !self.reduceMotion, Motion.enabled, !self.finished {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSince(self.started)
                    let progress = min(1, max(0, elapsed / 1.7))
                    for index in 0..<28 {
                        let lane = Double(index) / 27
                        let wave = sin(Double(index) * 2.4)
                        let x = size.width * lane + wave * 20 * progress
                        let y = -20 + progress * (size.height * 0.75 + Double(index % 5) * 25)
                        var shard = context
                        shard.opacity = max(0, 1 - progress)
                        shard.translateBy(x: x, y: y)
                        shard.rotate(by: .degrees(Double(index * 29) + progress * 180))
                        shard.fill(
                            Path(roundedRect: CGRect(x: -3, y: -6, width: 6, height: 12), cornerRadius: 2),
                            with: .color(index.isMultiple(of: 2) ? Theme.lime : Theme.violet)
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                self.started = Date()
                do {
                    try await Task.sleep(for: .seconds(1.8))
                    self.finished = true
                } catch {
                    // Leaving the result cancels its decorative effect.
                }
            }
        }
    }
}
