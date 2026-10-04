import SwiftUI

/// The headline score dial.
///
/// Draws the band boundaries on the scale, an arc for the estimate, and a lighter arc for
/// the confidence interval. Showing the interval *on the dial* rather than as a caption
/// is the point: the uncertainty is part of the picture, not a footnote.
struct ScoreGaugeView: View {
    let estimate: Double
    let confidenceLow: Double
    let confidenceHigh: Double
    let percentile: Double
    let band: IQBand?

    private static let scale: ClosedRange<Double> = 55...165

    // MARK: - Precomputed geometry

    /// A trimmed arc, expressed in SwiftUI's `trim` units.
    private struct Arc {
        let start: CGFloat
        let end: CGFloat
    }

    /// Maps a value on the IQ scale onto the sweep, then into `trim` units.
    ///
    /// Broken into small typed steps on purpose: the single-expression version exceeded
    /// the type checker's budget.
    private static func arc(from low: Double, to high: Double) -> Arc {
        let span = scale.upperBound - scale.lowerBound
        let clampLow = max(scale.lowerBound, min(scale.upperBound, low))
        let clampHigh = max(scale.lowerBound, min(scale.upperBound, high))
        let tLow: Double = (clampLow - scale.lowerBound) / span
        let tHigh: Double = (clampHigh - scale.lowerBound) / span
        let startDegrees: Double = -210 + tLow * 240
        let endDegrees: Double = -210 + tHigh * 240
        let start = clampToUnit(CGFloat((startDegrees + 390) / 360))
        let end = clampToUnit(CGFloat((endDegrees + 390) / 360))
        return Arc(start: start, end: Swift.max(start + 0.001, end))
    }

    private static func arc(to value: Double) -> Arc {
        self.arc(from: scale.lowerBound, to: value)
    }

    private var bandArcs: [(band: ScaleBand, arc: Arc)] {
        ScaleBand.allCases.map { band in
            (band, Arc(start: Self.arc(from: band.lowerBound, to: band.upperBound).start,
                       end: Self.arc(from: band.lowerBound, to: band.upperBound).end))
        }
    }

    private var confidenceArc: Arc { Self.arc(from: self.confidenceLow, to: self.confidenceHigh) }
    private var estimateArc: Arc { Self.arc(to: self.estimate) }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                self.bandLayer
                self.confidenceLayer
                self.estimateLayer
                self.needle
                self.centreLabel
            }
            .frame(width: 240, height: 240)
            .padding(.bottom, 8)

            self.bandPill
            self.figures
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estimated IQ \(Int(self.estimate.rounded()))")
        .accessibilityValue(self.accessibilityValue)
    }

    // MARK: - Layers

    private var bandLayer: some View {
        ForEach(self.bandArcs, id: \.band) { entry in
            Circle()
                .trim(from: entry.arc.start, to: entry.arc.end)
                .stroke(
                    entry.band.tint.opacity(entry.band == .average ? 0.32 : 0.16),
                    style: StrokeStyle(lineWidth: 16, lineCap: .butt)
                )
                .rotationEffect(.degrees(90))
        }
    }

    private var confidenceLayer: some View {
        Circle()
            .trim(from: self.confidenceArc.start, to: self.confidenceArc.end)
            .stroke(Theme.accent.opacity(0.32), style: StrokeStyle(lineWidth: 16))
            .rotationEffect(.degrees(90))
    }

    private var estimateLayer: some View {
        Circle()
            .trim(from: 0, to: self.estimateArc.end)
            .stroke(
                AngularGradient(
                    colors: [Theme.incorrect, Theme.hint, Theme.correct],
                    center: .center,
                    startAngle: .degrees(-210), endAngle: .degrees(30)
                ),
                style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            .rotationEffect(.degrees(90))
    }

    private var needle: some View {
        Capsule()
            .fill(Theme.textPrimary)
            .frame(width: 3, height: 42)
            .offset(y: -21)
            .rotationEffect(self.needleAngle)
    }

    private var needleAngle: Angle {
        let span = Self.scale.upperBound - Self.scale.lowerBound
        let clamped = max(Self.scale.lowerBound, min(Self.scale.upperBound, self.estimate))
        let t: Double = (clamped - Self.scale.lowerBound) / span
        return .degrees(-210 + t * 240 + 90)
    }

    private var centreLabel: some View {
        VStack(spacing: -2) {
            Text(String(Int(self.estimate.rounded())))
                .font(.mono(52, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
            Text("ESTIMATED IQ")
                .font(.app(.caption2, size: 9, weight: .heavy))
                .tracking(1.6)
                .foregroundStyle(Theme.textTertiary)
        }
        .offset(y: 26)
    }

    private var bandPill: some View {
        Group {
            if let band {
                Text(band.title.uppercased())
                    .font(.app(.caption, size: 11, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.black.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background { Capsule().fill(band.tint) }
            } else {
                Label("Band straddles a boundary", systemImage: "arrow.left.and.right")
                    .font(.app(.caption, size: 11, weight: .semibold))
                    .foregroundStyle(Theme.hint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background { Capsule().fill(Theme.hint.opacity(0.16)) }
            }
        }
    }

    private var figures: some View {
        HStack(spacing: 16) {
            figure(String(Int(self.percentile.rounded())) + "th", "percentile")
            figure(
                "\(Int(self.confidenceLow.rounded()))–\(Int(self.confidenceHigh.rounded()))",
                "95% range"
            )
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.mono(17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.app(.caption2, size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var accessibilityValue: String {
        let name = self.band?.title ?? "band not certain"
        let percentile = Int(self.percentile.rounded())
        let low = Int(self.confidenceLow.rounded())
        let high = Int(self.confidenceHigh.rounded())
        return "\(name) band, around the \(percentile)th percentile, range \(low) to \(high)"
    }
}

/// Clamps to the 0...1 range `trim` expects.
private func clampToUnit(_ value: CGFloat) -> CGFloat {
    if value < 0 { return 0 }
    if value > 1 { return 1 }
    return value
}

extension IQBand {
    /// The colour used for this band on the dial and the pill.
    var tint: Color {
        switch self {
        case .veryLow: return Theme.incorrect
        case .low: return Theme.hint
        case .average: return Theme.accent
        case .high: return Color(red: 0.45, green: 0.80, blue: 0.75)
        case .veryHigh: return Theme.correct
        }
    }
}

enum ScaleBand: CaseIterable {
    case veryLow, low, average, high, veryHigh

    var lowerBound: Double {
        switch self {
        case .veryLow: return 55
        case .low: return 70
        case .average: return 85
        case .high: return 115
        case .veryHigh: return 130
        }
    }

    var upperBound: Double {
        switch self {
        case .veryLow: return 70
        case .low: return 85
        case .average: return 115
        case .high: return 130
        case .veryHigh: return 165
        }
    }

    var tint: Color {
        switch self {
        case .veryLow: return Theme.incorrect
        case .low: return Theme.hint
        case .average: return Theme.accent
        case .high: return Color(red: 0.45, green: 0.80, blue: 0.75)
        case .veryHigh: return Theme.correct
        }
    }
}