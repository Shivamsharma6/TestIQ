import SwiftUI

/// The eight-axis brain profile.
///
/// Drawn in a `Canvas` because a radar chart needs polygon maths on every frame, and
/// animating eight separate SwiftUI shapes to do that is both slower and harder to keep
/// consistent. Each axis is labelled with its short name and coloured by magnitude, so the
/// shape and the colour agree.
struct RadarChartView: View {
    let scores: [DomainScore]
    var size: CGFloat = 280
    var sweep: Double = 1.0

    private var ordered: [DomainScore] {
        let byDomain = Dictionary(uniqueKeysWithValues: self.scores.map { ($0.domain, $0) })
        return CognitiveDomain.radarOrder.compactMap { byDomain[$0] }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Canvas { context, canvasSize in
                    let centre = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                    let radius = min(canvasSize.width, canvasSize.height) / 2 - 34
                    self.drawRings(in: &context, centre: centre, radius: radius)

                    let points = self.polygon(centre: centre, radius: radius)
                    if points.count >= 3 {
                        var filled = Path()
                        filled.move(to: points[0])
                        for point in points.dropFirst() { filled.addLine(to: point) }
                        filled.closeSubpath()

                        context.fill(
                            filled,
                            with: .radialGradient(
                                Gradient(colors: [Theme.accent.opacity(0.45), Theme.accent.opacity(0.12)]),
                                center: centre, startRadius: 0, endRadius: radius
                            )
                        )
                        context.stroke(
                            filled, with: .color(Theme.accent),
                            style: StrokeStyle(lineWidth: 2.5, lineJoin: .round)
                        )

                        for (index, point) in points.enumerated() {
                            let score = self.ordered[index]
                            context.fill(
                                Path(ellipseIn: CGRect(x: point.x - 4.5, y: point.y - 4.5, width: 9, height: 9)),
                                with: .color(Theme.scale(for: score.index / 100))
                            )
                        }
                    }
                }
                .frame(width: self.size, height: self.size)

                axisLabels
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Radar chart of all eight abilities")
        .accessibilityValue(
            self.ordered
                .map { "\($0.domain.shortTitle) \(Int($0.index)) out of 100" }
                .joined(separator: ", ")
        )
    }

    private func drawRings(in context: inout GraphicsContext, centre: CGPoint, radius: CGFloat) {
        for step in 1...4 {
            let fraction = CGFloat(step) / 4
            var ring = Path()
            let count = max(3, self.ordered.count)
            for index in 0...count {
                let angle = Self.angle(for: index, count: count)
                let point = CGPoint(x: centre.x + cos(angle) * radius * fraction,
                                    y: centre.y + sin(angle) * radius * fraction)
                index == 0 ? ring.move(to: point) : ring.addLine(to: point)
            }
            ring.closeSubpath()
            context.stroke(ring, with: .color(.white.opacity(step == 4 ? 0.16 : 0.07)), lineWidth: 1)
        }

        // Spokes.
        let count = max(3, self.ordered.count)
        for index in 0..<count {
            let angle = Self.angle(for: index, count: count)
            var spoke = Path()
            spoke.move(to: centre)
            spoke.addLine(to: CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius))
            context.stroke(spoke, with: .color(.white.opacity(0.07)), lineWidth: 1)
        }
    }

    private func polygon(centre: CGPoint, radius: CGFloat) -> [CGPoint] {
        let count = max(3, self.ordered.count)
        return self.ordered.enumerated().map { index, score in
            let angle = Self.angle(for: index, count: count)
            // `sweep` animates the chart growing out from the centre.
            let magnitude = CGFloat(score.index / 100) * CGFloat(self.sweep)
            return CGPoint(
                x: centre.x + cos(angle) * radius * magnitude,
                y: centre.y + sin(angle) * radius * magnitude
            )
        }
    }

    private static func angle(for index: Int, count: Int) -> CGFloat {
        CGFloat(Double(index) / Double(count) * 2 * .pi - .pi / 2)
    }

    /// Labels are laid out outside the ring by hand so each one sits on the correct side
    /// of the chart and stays upright.
    private var axisLabels: some View {
        let count = max(3, self.ordered.count)
        return GeometryReader { proxy in
            let centre = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = min(proxy.size.width, proxy.size.height) / 2 - 34

            ForEach(Array(self.ordered.enumerated()), id: \.element.domain) { index, score in
                let angle = Self.angle(for: index, count: count)
                let point = CGPoint(x: centre.x + cos(angle) * (radius + 16),
                                    y: centre.y + sin(angle) * (radius + 14))
                VStack(spacing: 1) {
                    Text(score.domain.shortTitle)
                        .font(.app(.caption2, size: 9, weight: .heavy))
                        .tracking(0.4)
                        .foregroundStyle(Theme.textSecondary)
                    Text(String(Int(score.index)))
                        .font(.mono(11, weight: .bold))
                        .foregroundStyle(Theme.scale(for: score.index / 100))
                }
                .position(point)
            }
        }
    }
}

/// A horizontal domain bar with its item count and accuracy.
struct DomainRowView: View {
    let score: DomainScore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(self.score.domain.shortTitle)
                    .font(.app(.subheadline, size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(self.subtitle)
                    .font(.app(.caption2, size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(width: 96, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.scale(for: self.score.index / 100).opacity(0.75),
                                         Theme.scale(for: self.score.index / 100)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(3, proxy.size.width * self.score.index / 100))
                }
            }
            .frame(height: 9)
            .animation(Motion.enabled ? Motion.settle : nil, value: self.score.index)

            Text("\(Int(self.score.index))")
                .font(.mono(15, weight: .bold))
                .foregroundStyle(Theme.scale(for: self.score.index / 100))
                .frame(width: 32, alignment: .trailing)
        }
        .frame(minHeight: 34)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.score.domain.title)
        .accessibilityValue(self.accessibilityValue)
    }

    private var subtitle: String {
        guard self.score.itemCount > 0 else { return "inferred from speed" }
        let accuracy = Int(self.score.accuracy * 100)
        return "\(self.score.itemCount) \(self.score.itemCount == 1 ? "item" : "items") · \(accuracy)% right"
    }

    private var accessibilityValue: String {
        "indexed \(Int(self.score.index)) out of 100"
            + (self.score.itemCount > 0 ? " from \(self.score.itemCount) items" : "")
    }
}