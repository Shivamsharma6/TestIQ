import SwiftUI

/// Draws a `ShapeSpec` using the polygons in `ShapeGeometry`.
///
/// The view owns presentation only — fill, rotation, mirroring and arrangement. All shape
/// maths lives in `Core` where it can be asserted on, which is what guarantees an option can
/// never render as an invisible sliver.
struct ShapeView: View {
    let spec: ShapeSpec
    var tint: Color = Theme.accent
    var lineWidthRatio: CGFloat = 0.075

    var body: some View {
        Canvas { context, size in
            self.draw(in: &context, size: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let side = Swift.min(size.width, size.height)
        guard side > 1 else { return }
        let stroke = Swift.max(1.5, side * self.lineWidthRatio)

        for placement in self.placements(in: size, side: side) {
            let path = Self.path(
                spec: self.spec,
                radius: placement.radius,
                origin: placement.center
            )
            guard !path.isEmpty else { continue }

            switch self.spec.fill {
            case .solid:
                context.fill(path, with: .color(self.tint))

            case .hollow:
                context.stroke(path, with: .color(self.tint), lineWidth: stroke)

            case .dotted:
                context.stroke(
                    path, with: .color(self.tint),
                    style: StrokeStyle(lineWidth: stroke, lineCap: .round, dash: [stroke * 0.4, stroke * 1.1])
                )

            case .striped:
                // `drawLayer` is SwiftUI's clip-and-draw, which is what makes the stripes
                // read as *inside* the shape rather than across the whole tile.
                context.drawLayer { layer in
                    layer.clip(to: path)
                    let step = Swift.max(4, side / 14)
                    var y: CGFloat = -size.height
                    while y < size.height * 2 {
                        var line = Path()
                        line.move(to: CGPoint(x: 0, y: y))
                        line.addLine(to: CGPoint(x: size.width, y: y - size.width))
                        layer.stroke(line, with: .color(self.tint), lineWidth: stroke * 0.5)
                        y += step
                    }
                }
                context.stroke(path, with: .color(self.tint.opacity(0.45)), lineWidth: stroke * 0.35)

            case .halfTop, .halfBottom:
                context.fill(path, with: .color(self.tint.opacity(0.34)))
                context.stroke(path, with: .color(self.tint), lineWidth: stroke)
                // The dashed rule is what makes "half filled" readable at a glance.
                let isTop = self.spec.fill == .halfTop
                let y = isTop ? placement.center.y - placement.radius : placement.center.y
                var divider = Path()
                divider.move(to: CGPoint(x: placement.center.x - placement.radius, y: y))
                divider.addLine(to: CGPoint(x: placement.center.x + placement.radius, y: y))
                context.stroke(
                    divider, with: .color(self.tint),
                    style: StrokeStyle(lineWidth: stroke * 0.7, dash: [2, 2])
                )
            }
        }
    }

    private static func path(spec: ShapeSpec, radius: CGFloat, origin: CGPoint) -> Path {
        let vertices = ShapeGeometry.outline(for: spec.shape, radius: Double(radius))
        guard !vertices.isEmpty else { return Path() }

        var transform = CGAffineTransform(translationX: origin.x, y: origin.y)
        transform = transform.rotated(by: CGFloat(Double(spec.rotation) * .pi / 180))
        if spec.handed < 0 {
            transform = transform.scaledBy(x: -1, y: 1)
        }

        var path = Path()
        path.addLines(vertices.map { vertex in
            CGPoint(x: CGFloat(vertex.x), y: CGFloat(vertex.y)).applying(transform)
        })
        path.closeSubpath()
        return path
    }

    /// Positions for the arrangement's elements.
    private func placements(in size: CGSize, side: CGFloat) -> [(center: CGPoint, radius: CGFloat)] {
        let count = Swift.max(1, Swift.min(spec.count, 9))
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        switch spec.arrangement {
        case .single:
            return [(center, side * 0.42)]

        case .row:
            let radius = side * 0.42 / CGFloat(count)
            let step = radius * 2.4
            let total = step * CGFloat(count - 1)
            return (0..<count).map { index in
                (CGPoint(x: center.x - total / 2 + step * CGFloat(index), y: center.y), radius)
            }

        case .ring:
            let radius = side * 0.13
            let orbit = side * 0.29
            return (0..<count).map { index in
                let angle = 2 * Double.pi * Double(index) / Double(count) - Double.pi / 2
                return (
                    CGPoint(x: center.x + orbit * CGFloat(cos(angle)),
                            y: center.y + orbit * CGFloat(sin(angle))),
                    radius
                )
            }

        case .cluster:
            // Deliberately uneven, so elements overlap. Overlapping shapes are the whole
            // point of the counting items.
            let pattern: [(CGFloat, CGFloat)] = [
                (0, 0), (0.30, -0.16), (-0.26, -0.20), (-0.18, 0.28),
                (0.28, 0.24), (0, -0.42), (0.04, 0.44), (-0.40, 0.04),
                (0.44, -0.02),
            ]
            let unit = side / CGFloat(count)
            let radius = Swift.min(side * 0.20, unit * (count <= 5 ? 0.72 : 0.62))
            return (0..<Swift.min(count, pattern.count)).map { index in
                let (dx, dy) = pattern[index]
                return (CGPoint(x: center.x + dx * side * 0.34, y: center.y + dy * side * 0.34), radius)
            }
        }
    }
}