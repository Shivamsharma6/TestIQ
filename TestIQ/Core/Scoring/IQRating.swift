import Foundation

/// Classification bands, in the standard deviation convention (mean 100, SD 15).
public enum IQBand: String, Sendable, Codable, CaseIterable {
    case veryLow, low, average, high, veryHigh

    public var title: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .average: return "Average"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }

    public var blurb: String {
        switch self {
        case .veryLow: return "Below roughly 1 in 20 people."
        case .low: return "Below roughly 1 in 3 people."
        case .average: return "Roughly 2 in 3 people score in this range."
        case .high: return "Above roughly 2 in 3 people."
        case .veryHigh: return "Above roughly 19 in 20 people."
        }
    }

    public static func band(for iq: Double) -> IQBand {
        switch iq {
        case ..<70: return .veryLow
        case ..<85: return .low
        case ..<115: return .average
        case ..<130: return .high
        default: return .veryHigh
        }
    }

    public var lowerBound: Double {
        switch self {
        case .veryLow: return 0
        case .low: return 70
        case .average: return 85
        case .high: return 115
        case .veryHigh: return 130
        }
    }

    public var upperBound: Double {
        switch self {
        case .veryLow: return 70
        case .low: return 85
        case .average: return 115
        case .high: return 130
        case .veryHigh: return 200
        }
    }
}

/// The θ → IQ conversion. Pure functions only, so every number the report shows can be
/// reproduced in a test.
///
/// θ is a latent ability scale where 2.80 is defined as population-average and 0.85 is
/// one standard deviation of item score. Mapping θ to a mean-100/SD-15 scale keeps the
/// reported number familiar to the player while the uncertainty stays honest.
public enum IQRating {
    /// θ value corresponding to the population mean.
    public static let meanTheta = 2.80
    /// One standard deviation of θ, in θ units.
    public static let thetaSigma = 0.85

    public static let iqMean = 100.0
    public static let iqSigma = 15.0

    /// Standard normal CDF. θ is converted to z first.
    public static func percentile(forTheta theta: Double) -> Double {
        100 * MathKit.normalCDF(self.z(forTheta: theta))
    }

    public static func z(forTheta theta: Double) -> Double {
        (theta - self.meanTheta) / self.thetaSigma
    }

    public static func iq(forTheta theta: Double) -> Double {
        self.iqMean + self.iqSigma * self.z(forTheta: theta)
    }

    public static func theta(forIQ iq: Double) -> Double {
        self.meanTheta + self.thetaSigma * ((iq - self.iqMean) / self.iqSigma)
    }

    /// Standard error of the composite θ estimate, widened when the player's performance
    /// was internally inconsistent. An inconsistent run genuinely is less informative
    /// than a consistent one, even at the same item count, so the interval must widen.
    public static func standardError(itemCount: Int, dispersion: Double) -> Double {
        let effective = Double(max(itemCount, 8))
        let base = self.thetaSigma / (effective / 12.0).squareRoot()
        return base + 0.35 * MathKit.clamp(dispersion, 0, 2.5)
    }

    /// Score for a single item.
    ///
    /// Correctness is all-or-nothing, but speed and independence (hints) modulate the
    /// credit. Solving a 4.0 item in half the time with no hints is stronger evidence
    /// than solving it slowly with two hints — which is exactly what a real adaptive
    /// battery infers.
    public static func itemScore(
        theta: Double, correct: Bool, elapsed: TimeInterval, timeLimit: TimeInterval, hintsUsed: Int
    ) -> Double {
        guard correct else { return 0 }
        let ratio = timeLimit > 0 ? Double(elapsed) / timeLimit : 1
        let timeBonus = 0.35 * (1 - MathKit.clamp(ratio, 0, 1.5))
        let hintPenalty = 0.45 * Double(hintsUsed)
        return MathKit.clamp(theta + timeBonus - hintPenalty, 0, 6)
    }

    /// The 95 % interval around an IQ estimate, clamped to something a human could
    /// plausibly score.
    public static func confidenceInterval(theta: Double, itemCount: Int, dispersion: Double) -> (low: Double, high: Double) {
        let z = self.z(forTheta: theta)
        let se = self.standardError(itemCount: itemCount, dispersion: dispersion)
        let low = self.iqMean + self.iqSigma * (z - 1.96 * se)
        let high = self.iqMean + self.iqSigma * (z + 1.96 * se)
        return (low: MathKit.clamp(low, 55, 165), MathKit.clamp(high, 55, 165))
    }

    /// The band is only claimed when the whole confidence interval falls inside it.
    /// Otherwise the player's result genuinely straddles a boundary and asserting a
    /// category would be misleading.
    public static func confidentBand(estimate: Double, low: Double, high: Double) -> IQBand? {
        let centre = IQBand.band(for: estimate)
        guard centre.lowerBound <= low, high <= centre.upperBound else { return nil }
        return centre
    }

    /// Population-standard-deviation denominator, because the reported dispersion is a
    /// description of this player's run rather than a sample estimate.
    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance.squareRoot()
    }
}