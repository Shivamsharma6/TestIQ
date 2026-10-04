import Foundation

/// One axis of the brain profile.
public struct DomainScore: Identifiable, Sendable, Hashable, Codable {
    public let domain: CognitiveDomain
    /// θ after shrinkage toward the composite. This is what the report shows.
    public let theta: Double
    /// θ from this domain's own items only, before shrinkage. Kept for transparency.
    public let rawTheta: Double
    public let itemCount: Int
    public let accuracy: Double
    /// Median fraction of the time allowance consumed, correct answers only.
    public let medianLatencyRatio: Double

    public var id: String { self.domain.rawValue }

    /// 0–100 presentation score used by the radar chart and the domain bars.
    public var index: Double {
        100 * MathKit.normalCDF(IQRating.z(forTheta: self.theta))
    }

    public var percentile: Double { 100 * MathKit.normalCDF(IQRating.z(forTheta: self.theta)) }

    public var isMeasured: Bool { self.itemCount > 0 }
}

/// A recurring, specific mistake. Produced by grouping errors on `skillTag`, which is
/// how the report can say "you missed alternating-difference sequences three times"
/// instead of the useless "try more sequences".
public struct ErrorCluster: Identifiable, Sendable, Hashable, Codable {
    public let tag: String
    public let kind: PuzzleKind
    public let domain: CognitiveDomain
    public let count: Int
    public let levelIDs: [Int]

    public var id: String { self.tag }
}

public struct LevelBreakdown: Identifiable, Sendable, Hashable, Codable {
    public let levelID: Int
    public let name: String
    public let stars: Int
    public let accuracy: Double
    public let itemCount: Int
    public let score: Int

    public var id: Int { self.levelID }
}

/// The complete, computed result of a full ascent.
public struct Assessment: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID
    public let generatedAt: Date
    public let compositeTheta: Double
    public let iqEstimate: Double
    public let percentile: Double
    public let confidenceLow: Double
    public let confidenceHigh: Double
    /// `nil` when the confidence interval straddles a band boundary.
    public let band: IQBand?
    public let domainScores: [DomainScore]
    public let totalItems: Int
    public let overallAccuracy: Double
    public let bestStreak: Int
    public let levelsCleared: Int
    public let totalStars: Int
    /// Standard deviation of item scores. Drives how wide the confidence interval is.
    public let dispersion: Double
    public let errorClusters: [ErrorCluster]
    public let strengths: [DomainScore]
    public let growthAreas: [DomainScore]
    public let levelBreakdown: [LevelBreakdown]
    /// Plain-language headline written from the numbers, not boilerplate.
    public let headline: String

    public var confidenceWidth: Double { self.confidenceHigh - self.confidenceLow }

    public var isReliable: Bool { self.totalItems >= 40 && self.confidenceWidth <= 24 }

    /// Domains with enough evidence to be worth quoting back to the player.
    public var measuredDomains: [DomainScore] { self.domainScores.filter(\.isMeasured) }

    public func domainScore(_ domain: CognitiveDomain) -> DomainScore? {
        self.domainScores.first { $0.domain == domain }
    }

    /// Honest framing of what this number is, shown next to the headline so the estimate
    /// is never mistaken for a clinical measurement.
    public var reliabilityNote: String {
        if self.totalItems < 20 {
            return "Based on \(self.totalItems) answers — treat this as a rough guide, not a measurement."
        }
        if !self.isReliable {
            return "Based on \(self.totalItems) answers. The wide range reflects how varied your performance was; replay a few floors to tighten it."
        }
        return "Based on \(self.totalItems) answers with consistent performance — a reasonably tight estimate."
    }

    public static let empty = Assessment(
        id: UUID(), generatedAt: Date(), compositeTheta: IQRating.meanTheta,
        iqEstimate: IQRating.iqMean, percentile: 50,
        confidenceLow: 85, confidenceHigh: 115, band: nil,
        domainScores: [], totalItems: 0, overallAccuracy: 0, bestStreak: 0,
        levelsCleared: 0, totalStars: 0, dispersion: 0,
        errorClusters: [], strengths: [], growthAreas: [], levelBreakdown: [],
        headline: "Complete the ascent to unlock your assessment."
    )
}

/// A concrete, actionable piece of advice. Nothing in the report is allowed to be
/// generic — every card names a real number and a real technique.
public struct CoachingTip: Identifiable, Sendable, Hashable, Codable {
    public enum Kind: String, Sendable, Codable {
        /// A whole cognitive domain sits below the composite.
        case domainWeakness
        /// One specific item type is being missed repeatedly.
        case errorCluster
        /// Raw speed is the limiting factor rather than accuracy.
        case pacing
    }

    public let id: UUID
    public let kind: Kind
    public let title: String
    /// The observation, stated with the actual numbers.
    public let evidence: String
    /// The named technique that fixes this specific failure mode.
    public let technique: String
    /// A drill specific enough to actually perform.
    public let drill: String
    /// The mistake that keeps this weakness alive. The explicit "how not to".
    public let pitfall: String
    public let domain: CognitiveDomain
    /// Floor to replay to retest this area.
    public let suggestedLevelID: Int?
}