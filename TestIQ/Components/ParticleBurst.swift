import SwiftUI

/// A short burst of particles at a tap location.
///
/// Drawn in a `Canvas` driven by `TimelineView` rather than as many animating views, so a
/// burst costs one view and one timeline instead of twenty. Under Reduce Motion it is
/// skipped entirely rather than merely shortened.
struct ParticleBurst: View {
    let token: Int
    var tint: Color = Theme.correct
    var origin: UnitPoint = .center

    @State private var started: Date?

    private struct Particle {
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let delay: Double
        let spin: Double
    }

    var body: some View {
        if Motion.enabled, self.token > 0 {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let now = self.started ?? timeline.date
                    let elapsed = timeline.date.timeIntervalSince(now)
                    let particles = Self.make(count: 16)

                    for particle in particles {
                        let local = elapsed - particle.delay
                        guard local > 0, local < 0.75 else { continue }
                        let progress = local / 0.75
                        let eased = 1 - pow(1 - progress, 3)

                        let radius = size.width * 0.5
                        let origin = CGPoint(
                            x: size.width * self.origin.x,
                            y: size.height * self.origin.y
                        )
                        let point = CGPoint(
                            x: origin.x + CGFloat(cos(particle.angle)) * particle.distance * eased * radius,
                            y: origin.y + CGFloat(sin(particle.angle)) * particle.distance * eased * radius
                            + CGFloat(eased * eased) * 26
                        )

                        var shard = context
                        shard.opacity = 1 - progress
                        shard.translateBy(x: point.x, y: point.y)
                        shard.rotate(by: .radians(particle.spin * progress * 4))
                        shard.fill(
                            Path(roundedRect: CGRect(x: -particle.size / 2, y: -particle.size / 2,
                                                    width: particle.size, height: particle.size * 1.7),
                                 cornerRadius: particle.size * 0.3),
                            with: .color(self.tint)
                        )
                    }
                }
                .onChange(of: self.token) { _, _ in self.started = timeline.date }
            }
        }
    }

    private static func make(count: Int) -> [Particle] {
        var generator = SeededGenerator(seed: UInt64(count &* 7919 &+ 13))
        return (0..<count).map { _ in
            Particle(
                angle: generator.nextDouble(in: 0...(2 * .pi)),
                distance: generator.nextDouble(in: 0.55...1.05),
                size: generator.nextDouble(in: 6...13),
                delay: generator.nextDouble(in: 0...0.08),
                spin: generator.nextDouble(in: -3...3)
            )
        }
    }
}

/// Confetti for the level-complete moment.
struct ConfettiView: View {
    var isActive: Bool
    var pieces: Int = 60

    var body: some View {
        if Motion.enabled, self.isActive {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let generator = SeededGenerator(seed: 4_242)
                    for _ in 0..<self.pieces {
                        var roll = generator
                        let startX = roll.nextDouble(in: 0...1)
                        let speed = roll.nextDouble(in: 0.55...1.25)
                        let sway = roll.nextDouble(in: 14...46)
                        let phase = roll.nextDouble(in: 0...(2 * .pi))
                        let chipSize = roll.nextDouble(in: 5...11)
                        let hue = roll.nextDouble(in: 0...1)

                        let t = timeline.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 9)
                        let progress = (t * speed).truncatingRemainder(dividingBy: 1)

                        let x = startX * size.width + sin(t * 2 + phase) * sway
                        let y = progress * (size.height + 90) - 40

                        var shard = context
                        shard.opacity = progress > 0.85 ? (1 - progress) / 0.15 : 1
                        shard.translateBy(x: x, y: y)
                        shard.rotate(by: .radians(t * 3 + phase))
                        shard.fill(
                            Path(roundedRect: CGRect(
                                x: -chipSize / 2, y: -chipSize / 4,
                                width: chipSize, height: chipSize / 2
                             ), cornerRadius: 1.5),
                            with: .color(hue < 0.34 ? Theme.accent : (hue < 0.67 ? Theme.correct : Theme.hint))
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
    }
}