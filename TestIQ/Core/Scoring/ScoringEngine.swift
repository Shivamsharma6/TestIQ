import Foundation

/// Turns a `RunSummary` into an `Assessment`. Pure, deterministic and free of any UI or
/// Foundation-side effects, which is what makes the headline number in the app testable.
public enum ScoringEngine {
    /// Empirical Bayes weight applied to a domain's own estimate. Five pseudo-items of
    /// evidence at the composite mean: enough that a single lucky item cannot create a
    /// fake superpower, little enough that four solid items still move the number.
    static let domainPriorWeight = 5.0

    /// A domain more than this far below the composite is reported as a growth area.
    static let weaknessThreshold = 0.40

    public static func assess(_ summary: RunSummary) -> Assessment {
        let bestResults = summary.bestByLevel
        let items = bestResults.flatMap(\.items)
        guard !items.isEmpty else { return .empty }

        let scores = items.map {
            IQRating.itemScore(
                theta: $0.theta, correct: $0.correct,
                elapsed: $0.elapsed, timeLimit: $0.timeLimit, hintsUsed: $0.hintsUsed
            )
        }
        let dispersion = IQRating.standardDeviation(scores)
        let globalTheta = scores.reduce(0, +) / Double(scores.count)

        let domainScores = self.buildDomainScores(items: items, globalTheta: globalTheta)
        let measured = domainScores.filter(\.isMeasured)
        let compositeTheta = measured.isEmpty
            ? globalTheta
            : measured.reduce(0) { $0 + $1.theta } / Double(measured.count)

        let interval = IQRating.confidenceInterval(
            theta: compositeTheta, itemCount: items.count, dispersion: dispersion
        )
        let estimate = IQRating.iq(forTheta: compositeTheta)

        let sorted = measured.sorted { $0.theta > $1.theta }
        let strengths = Array(sorted.prefix(3))
        let growthAreas = sorted
            .filter { compositeTheta - $0.theta > Self.weaknessThreshold }
            .reversed()

        let clusters = self.buildErrorClusters(items: items)
        let breakdown = bestResults.map { result in
            LevelBreakdown(
                levelID: result.levelID,
                name: LevelCatalog.level(result.levelID)?.name ?? "Floor \(result.levelID)",
                stars: result.stars,
                accuracy: result.accuracy,
                itemCount: result.items.count,
                score: result.score
            )
        }

        return Assessment(
            id: UUID(),
            generatedAt: Date(),
            compositeTheta: compositeTheta,
            iqEstimate: estimate,
            percentile: IQRating.percentile(forTheta: compositeTheta),
            confidenceLow: interval.low,
            confidenceHigh: interval.high,
            band: IQRating.confidentBand(estimate: estimate, low: interval.low, high: interval.high),
            domainScores: domainScores,
            totalItems: items.count,
            overallAccuracy: summary.overallAccuracy,
            bestStreak: bestResults.map(\.bestStreak).max() ?? 0,
            levelsCleared: bestResults.filter(\.isCleared).count,
            totalStars: bestResults.reduce(0) { $0 + $1.stars },
            dispersion: dispersion,
            errorClusters: clusters,
            strengths: Array(strengths),
            growthAreas: Array(growthAreas),
            levelBreakdown: breakdown,
            headline: self.headline(
                estimate: estimate, percentile: IQRating.percentile(forTheta: compositeTheta),
                band: IQRating.confidentBand(estimate: estimate, low: interval.low, high: interval.high),
                strengths: Array(strengths), growthCount: growthAreas.count,
                accuracy: summary.overallAccuracy, itemCount: items.count
            )
        )
    }

    // MARK: - Domains

    private static func buildDomainScores(items: [ItemResult], globalTheta: Double) -> [DomainScore] {
        CognitiveDomain.radarOrder.map { domain in
            let domainItems = items.filter { $0.domain == domain }

            // Attention & Speed is measured across every item, not a subset.
            if domain == .speed {
                let correctItems = items.filter(\.correct)
                let theta = Self.speedTheta(from: correctItems, globalTheta: globalTheta)
                return DomainScore(
                    domain: domain,
                    theta: theta,
                    rawTheta: theta,
                    itemCount: correctItems.count,
                    accuracy: correctItems.isEmpty
                        ? 0 : Double(correctItems.count) / Double(max(items.count, 1)),
                    medianLatencyRatio: Self.medianLatencyRatio(correctItems)
                )
            }

            guard !domainItems.isEmpty else {
                return DomainScore(
                    domain: domain, theta: globalTheta, rawTheta: globalTheta,
                    itemCount: 0, accuracy: 0, medianLatencyRatio: 1
                )
            }

            let raw = domainItems.reduce(0.0) { $0 + Self.score($1) } / Double(domainItems.count)
            let n = Double(domainItems.count)
            let shrunk = (n * raw + Self.domainPriorWeight * globalTheta) / (n + Self.domainPriorWeight)
            return DomainScore(
                domain: domain,
                theta: shrunk,
                rawTheta: raw,
                itemCount: domainItems.count,
                accuracy: Double(domainItems.filter(\.correct).count) / n,
                medianLatencyRatio: Self.medianLatencyRatio(domainItems)
            )
        }
    }

    private static func score(_ item: ItemResult) -> Double {
        IQRating.itemScore(
            theta: item.theta, correct: item.correct,
            elapsed: item.elapsed, timeLimit: item.timeLimit, hintsUsed: item.hintsUsed
        )
    }

    /// Converts "how much of the allowance did correct answers consume" into a θ on the
    /// same scale as item difficulty, so the speed axis is comparable with the rest.
    private static func speedTheta(from correctItems: [ItemResult], globalTheta: Double) -> Double {
        guard !correctItems.isEmpty else { return globalTheta }
        let latency = Self.medianLatencyRatio(correctItems)
        // 20 % of the allowance used maps to θ ≈ 4.2; the full allowance maps to ≈ 1.5.
        return MathKit.clamp(4.2 - 3.0 * latency, 0.5, 5.0)
    }

    static func medianLatencyRatio(_ items: [ItemResult]) -> Double {
        let ratios = items.map(\.elapsedRatio).sorted()
        guard !ratios.isEmpty else { return 1 }
        let middle = ratios.count / 2
        return ratios.count.isMultiple(of: 2)
            ? (ratios[middle] + ratios[middle - 1]) / 2
            : ratios[middle]
    }

    // MARK: - Error clusters

    private static func buildErrorClusters(items: [ItemResult]) -> [ErrorCluster] {
        let wrong = items.filter { !$0.correct }
        guard !wrong.isEmpty else { return [] }

        let grouped = Dictionary(grouping: wrong, by: \.skillTag)
        return grouped
            .map { tag, group in
                ErrorCluster(
                    tag: tag,
                    kind: group[0].kind,
                    domain: group[0].domain,
                    count: group.count,
                    levelIDs: Array(Set(group.map(\.levelID))).sorted()
                )
            }
            // One missed item is noise, not a pattern. Two is a signal worth naming.
            .filter { $0.count >= 2 }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Narrative

    private static func headline(
        estimate: Double, percentile: Double, band: IQBand?,
        strengths: [DomainScore], growthCount: Int, accuracy: Double, itemCount: Int
    ) -> String {
        let rounded = Int(estimate.rounded())
        let strengthName = strengths.first?.domain.shortTitle ?? "consistency"
        var sentence: String
        if let band {
            sentence = "Estimated IQ \(rounded) · \(band.title) band, around the \(Int(percentile.rounded()))th percentile."
        } else {
            sentence = "Estimated IQ \(rounded), around the \(Int(percentile.rounded()))th percentile — your range straddles a band boundary, so treat the band as provisional."
        }

        var tail = "Your clearest edge is \(strengthName.lowercased())"
        if let top = strengths.first {
            tail += ", where you held an index of \(Int(top.index))"
        }
        tail += "."
        if growthCount > 0 {
            let count = growthCount == 1 ? "One area is" : "\(growthCount) areas are"
            tail += " \(count) dragging the composite down — the cards below say exactly how."
        } else if accuracy >= 0.85 {
            tail += " Nothing fell far enough below your average to count as a weak spot across \(itemCount) answers."
        }
        return sentence + " " + tail
    }
}