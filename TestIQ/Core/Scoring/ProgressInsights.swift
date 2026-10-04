import Foundation

nonisolated struct PracticeMetrics: Sendable, Equatable {
    let accuracy: Double
    /// Average of the median correct-response times in equally weighted matched groups.
    /// Both windows use the same groups; unavailable if either lacks correct samples.
    let medianCorrectSeconds: Double?
    let hintsPerItem: Double
    let itemCount: Int
}

nonisolated struct PracticeTrend: Sendable, Identifiable, Equatable {
    var id: Int { levelID }
    let levelID: Int
    let earlier: PracticeMetrics
    let recent: PracticeMetrics
    let roundsCompared: Int
    var accuracyChange: Double { recent.accuracy - earlier.accuracy }
    var isFasterWithoutAccuracyLoss: Bool {
        guard let before = earlier.medianCorrectSeconds,
              let after = recent.medianCorrectSeconds else { return false }
        return after < before && accuracyChange >= -0.0001
            && recent.hintsPerItem <= earlier.hintsPerItem + 0.0001
    }
}

/// Descriptive practice comparisons, never population norms or estimates of IQ.
nonisolated enum ProgressInsights {
    nonisolated private struct Stratum: Hashable, Sendable {
        let kind: PuzzleKind
        let difficulty: Int
        let allowance: Int
        nonisolated init(_ item: ItemResult) {
            kind = item.kind
            difficulty = Int((item.theta * 2).rounded())
            allowance = Int((item.timeLimit * 10).rounded())
        }
    }

    nonisolated static func trends(in history: [LevelResult]) -> [PracticeTrend] {
        var seen: Set<String> = []
        let unique = history.filter { seen.insert($0.id).inserted }
        return Dictionary(grouping: unique, by: \.levelID).compactMap { levelID, rounds in
            let ordered = rounds.sorted { $0.completedAt < $1.completedAt }
            guard ordered.count >= 4 else { return nil }
            // An early baseline versus a recent window, with no shared rounds.
            let window = min(3, ordered.count / 2)
            let first = Array(ordered.prefix(window))
            let last = Array(ordered.suffix(window))
            let before = Dictionary(grouping: first.flatMap(\.items).filter(valid), by: Stratum.init)
            let after = Dictionary(grouping: last.flatMap(\.items).filter(valid), by: Stratum.init)
            let common = Set(before.keys).intersection(after.keys)
            guard !common.isEmpty else { return nil }
            let beforeCount = common.reduce(0) { $0 + (before[$1]?.count ?? 0) }
            let afterCount = common.reduce(0) { $0 + (after[$1]?.count ?? 0) }
            guard beforeCount >= 5, afterCount >= 5 else { return nil }

            // Use the same pace groups in both windows. A missing correct answer must
            // not make a hard group disappear from just one side of the comparison.
            let paceGroups = common.filter {
                before[$0]!.contains(where: \.correct) && after[$0]!.contains(where: \.correct)
            }
            let earlier = metrics(before, groups: common, paceGroups: paceGroups)
            let recent = metrics(after, groups: common, paceGroups: paceGroups)
            return PracticeTrend(levelID: levelID, earlier: earlier, recent: recent,
                                 roundsCompared: window * 2)
        }.sorted { $0.levelID < $1.levelID }
    }

    nonisolated private static func valid(_ item: ItemResult) -> Bool {
        item.theta.isFinite && item.theta >= 0 && item.theta <= 10
            && item.timeLimit.isFinite && item.timeLimit > 0 && item.timeLimit < 3600
            && item.elapsed.isFinite && item.elapsed >= 0 && item.hintsUsed >= 0
    }

    nonisolated private static func metrics(
        _ samples: [Stratum: [ItemResult]], groups: Set<Stratum>, paceGroups: Set<Stratum>
    ) -> PracticeMetrics {
        let count = Double(groups.count)
        let accuracy = groups.reduce(0.0) { value, key in
            let items = samples[key]!
            return value + Double(items.filter(\.correct).count) / Double(items.count)
        } / count
        let hints = groups.reduce(0.0) { value, key in
            let items = samples[key]!
            return value + Double(items.reduce(0) { $0 + $1.hintsUsed }) / Double(items.count)
        } / count
        let pace: Double? = paceGroups.isEmpty ? nil : paceGroups.reduce(0.0) { value, key in
            let sorted = samples[key]!.filter(\.correct).map(\.elapsed).sorted()
            let middle = sorted.count / 2
            let median = sorted.count.isMultiple(of: 2)
                ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
            return value + median
        } / Double(paceGroups.count)
        return PracticeMetrics(accuracy: accuracy, medianCorrectSeconds: pace,
                               hintsPerItem: hints,
                               itemCount: groups.reduce(0) { $0 + samples[$1]!.count })
    }
}
