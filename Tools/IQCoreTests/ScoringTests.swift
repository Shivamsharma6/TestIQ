import XCTest
@testable import IQCore

final class ScoringEngineTests: XCTestCase {
    // MARK: - Builders

    private func item(
        level: Int = 1,
        kind: PuzzleKind = .sequence,
        theta: Double = 3.0,
        correct: Bool = true,
        elapsed: Double = 10,
        limit: Double = 30,
        hints: Int = 0,
        tag: String = "arithmetic-step"
    ) -> ItemResult {
        ItemResult(
            id: "\(level)-\(kind.rawValue)-\(theta)-\(correct)-\(elapsed)-\(hints)",
            levelID: level, kind: kind, domain: kind.domain, theta: theta,
            skillTag: tag, correct: correct, elapsed: elapsed,
            timeLimit: limit, hintsUsed: hints
        )
    }

    private func levelResult(
        _ id: Int, items: [ItemResult], stars: Int = 3, score: Int = 100, streak: Int = 4
    ) -> LevelResult {
        LevelResult(
            id: "L\(id)", levelID: id, items: items, stars: stars, score: score, bestStreak: streak
        )
    }

    /// A flawless run through every domain, answered fast and without hints.
    private func strongRun() -> RunSummary {
        var items: [ItemResult] = []
        var level = 1
        for kind in PuzzleKind.allCases {
            for index in 0..<3 {
                items.append(self.item(
                    level: level, kind: kind, theta: 3.2,
                    correct: index != 2, elapsed: 8, limit: 30, hints: 0
                ))
            }
            level += 1
        }
        return RunSummary(levelResults: [self.levelResult(1, items: items, stars: 3, score: 900, streak: 9)])
    }

    private func weakRun() -> RunSummary {
        var items: [ItemResult] = []
        var level = 1
        for kind in PuzzleKind.allCases {
            for index in 0..<3 {
                items.append(self.item(
                    level: level, kind: kind, theta: 3.0,
                    correct: index == 2, elapsed: 28, limit: 30, hints: 2
                ))
            }
            level += 1
        }
        return RunSummary(levelResults: [self.levelResult(1, items: items, stars: 1, score: 100, streak: 1)])
    }

    // MARK: - Tests

    func testEmptySummaryYieldsTheEmptyAssessment() {
        let assessment = ScoringEngine.assess(RunSummary(levelResults: []))
        XCTAssertEqual(assessment.totalItems, 0)
        XCTAssertTrue(assessment.domainScores.isEmpty)
        XCTAssertFalse(assessment.isReliable)
    }

    func testStrongRunScoresAboveWeakRun() {
        let strong = ScoringEngine.assess(self.strongRun())
        let weak = ScoringEngine.assess(self.weakRun())
        XCTAssertGreaterThan(strong.iqEstimate, weak.iqEstimate)
        XCTAssertGreaterThan(strong.percentile, weak.percentile)
        XCTAssertGreaterThan(strong.compositeTheta, weak.compositeTheta)
    }

    func testIQEstimateStaysInAPlausibleRange() {
        for run in [self.strongRun(), self.weakRun()] {
            let assessment = ScoringEngine.assess(run)
            XCTAssertGreaterThanOrEqual(assessment.iqEstimate, 55)
            XCTAssertLessThanOrEqual(assessment.iqEstimate, 165)
            XCTAssertGreaterThanOrEqual(assessment.percentile, 0)
            XCTAssertLessThanOrEqual(assessment.percentile, 100)
        }
    }

    func testAllEightDomainsAreAlwaysPresent() {
        let assessment = ScoringEngine.assess(self.strongRun())
        XCTAssertEqual(assessment.domainScores.count, CognitiveDomain.allCases.count)
        XCTAssertEqual(Set(assessment.domainScores.map(\.domain)), Set(CognitiveDomain.allCases))
        XCTAssertEqual(assessment.domainScores.map(\.domain), CognitiveDomain.radarOrder)
    }

    func testSpeedDomainIsMeasuredFromAllItemsNotJustItsOwn() {
        // `speed` has no puzzle kind, so it must still carry evidence.
        let assessment = ScoringEngine.assess(self.strongRun())
        let speed = assessment.domainScore(.speed)
        XCTAssertNotNil(speed)
        XCTAssertGreaterThan(speed?.itemCount ?? 0, 20)
    }

    func testUnmeasuredDomainsSitAtTheCompositeMean() {
        // A run with no spatial items at all: that axis must fall back to the mean rather
        // than to zero, which would otherwise read as a catastrophic weakness.
        let items = (0..<30).map { index in
            self.item(kind: index.isMultiple(of: 2) ? .sequence : .ratio,
                      correct: !index.isMultiple(of: 3), elapsed: 9)
        }
        let assessment = ScoringEngine.assess(RunSummary(levelResults: [self.levelResult(1, items: items)]))
        let spatial = assessment.domainScore(.spatial)
        XCTAssertEqual(spatial?.itemCount, 0)
        XCTAssertFalse(spatial?.isMeasured ?? true)
        XCTAssertEqual(spatial!.theta, globalMeanTheta(items), accuracy: 0.0001)
        XCTAssertGreaterThan(spatial!.index, 5, "an unmeasured axis must not be presented as a weakness")
    }

    /// The mean item score across a set, which is what unmeasured axes inherit.
    private func globalMeanTheta(_ items: [ItemResult]) -> Double {
        let scores = items.map {
            IQRating.itemScore(theta: $0.theta, correct: $0.correct,
                               elapsed: $0.elapsed, timeLimit: $0.timeLimit, hintsUsed: $0.hintsUsed)
        }
        return scores.reduce(0, +) / Double(scores.count)
    }

    func testThinEvidenceIsShrunkTowardsTheComposite() {
        // One brilliant spatial item must not create a "superior" spatial axis.
        var items: [ItemResult] = []
        for _ in 0..<20 {
            items.append(self.item(kind: .sequence, theta: 3.0, correct: false))
        }
        items.append(self.item(kind: .rotation, theta: 5.0, correct: true, elapsed: 2))

        let assessment = ScoringEngine.assess(RunSummary(levelResults: [self.levelResult(1, items: items)]))
        let spatial = assessment.domainScore(.spatial)
        let pattern = assessment.domainScore(.pattern)
        XCTAssertNotNil(spatial)
        XCTAssertNotNil(pattern)
        // The lone perfect hardest item scores far above anything else in the run, and
        // shrinkage must pull it most of the way back towards the composite.
        XCTAssertGreaterThan(spatial!.rawTheta, spatial!.theta)
        XCTAssertGreaterThan(spatial!.theta, pattern!.theta, "one good answer is still some evidence")
        XCTAssertLessThan(
            abs(spatial!.theta - assessment.compositeTheta),
            abs(spatial!.rawTheta - assessment.compositeTheta),
            "shrinkage must reduce the distance from the composite"
        )
    }

    func testErrorClustersNeedAtLeastTwoOccurrences() {
        let isolated = [
            self.item(kind: .rotation, correct: false, tag: "rotation-angle"),
            self.item(kind: .rotation, correct: false, tag: "mirror-handedness"),
        ]
        let assessment = ScoringEngine.assess(RunSummary(levelResults: [self.levelResult(1, items: isolated)]))
        XCTAssertTrue(assessment.errorClusters.isEmpty, "one-off errors are noise, not patterns")

        let repeated = [
            self.item(kind: .rotation, correct: false, tag: "rotation-angle"),
            self.item(kind: .rotation, correct: false, tag: "rotation-angle"),
            self.item(kind: .memorySequence, correct: false, tag: "echo-span"),
        ]
        let clustered = ScoringEngine.assess(RunSummary(levelResults: [self.levelResult(1, items: repeated)]))
        XCTAssertEqual(clustered.errorClusters.first?.tag, "rotation-angle")
        XCTAssertEqual(clustered.errorClusters.first?.count, 2)
    }

    func testWeakRunProducesGrowthAreasAndStrongRunProducesStrengths() {
        let weak = ScoringEngine.assess(self.weakRun())
        let strong = ScoringEngine.assess(self.strongRun())
        XCTAssertFalse(weak.strengths.isEmpty)
        XCTAssertFalse(strong.strengths.isEmpty)
        XCTAssertEqual(weak.strengths.map(\.theta), weak.strengths.map(\.theta).sorted(by: >))
        for growth in weak.growthAreas {
            XCTAssertLessThan(growth.theta, weak.compositeTheta)
        }
        // A growth area must be dominated by the strengths, never one of them.
        let strengthDomains = Set(weak.strengths.map(\.domain))
        for growth in weak.growthAreas {
            XCTAssertFalse(strengthDomains.contains(growth.domain))
        }
    }

    func testInconsistentPerformanceWidensTheInterval() {
        let consistent = ScoringEngine.assess(RunSummary(levelResults: [self.levelResult(1, items: (0..<40).map { _ in
            self.item(theta: 3.0, correct: true, elapsed: 12, limit: 30)
        })]))
        let erratic = ScoringEngine.assess(RunSummary(levelResults: [self.levelResult(1, items: (0..<40).map { index in
            self.item(
                theta: index.isMultiple(of: 2) ? 1.0 : 5.0,
                correct: !index.isMultiple(of: 2), elapsed: index.isMultiple(of: 2) ? 29 : 3, limit: 30
            )
        })]))
        XCTAssertGreaterThan(erratic.confidenceWidth, consistent.confidenceWidth)
        XCTAssertGreaterThan(erratic.dispersion, consistent.dispersion)
    }

    func testFewerItemsProduceAWiderInterval() {
        let few = ScoringEngine.assess(RunSummary(levelResults: [self.levelResult(1, items: (0..<10).map { _ in
            self.item(correct: true)
        })]))
        let many = ScoringEngine.assess(RunSummary(levelResults: [self.levelResult(1, items: (0..<80).map { _ in
            self.item(correct: true)
        })]))
        XCTAssertGreaterThan(few.confidenceWidth, many.confidenceWidth)
        XCTAssertFalse(few.isReliable)
        XCTAssertTrue(many.isReliable)
    }

    func testBestPerFloorIsUsedSoReplayingCannotLowerAScore() {
        let bad = self.levelResult(1, items: (0..<5).map { _ in self.item(correct: false) }, stars: 0, score: 0)
        let good = self.levelResult(1, items: (0..<5).map { _ in self.item(correct: true, elapsed: 4) }, stars: 3, score: 500)
        let summary = RunSummary(levelResults: [bad, good])
        XCTAssertEqual(summary.bestByLevel.count, 1)
        XCTAssertEqual(summary.bestByLevel.first?.score, 500)
        XCTAssertEqual(ScoringEngine.assess(summary).totalItems, 5)
    }

    func testUnclearedFloorsStillContributeEvidenceButDoNotCountAsCleared() {
        let summary = RunSummary(levelResults: [
            self.levelResult(1, items: (0..<4).map { _ in self.item(correct: true) }, stars: 3),
            self.levelResult(2, items: (0..<4).map { _ in self.item(correct: false) }, stars: 0),
        ])
        XCTAssertEqual(summary.overallAccuracy, 0.5, accuracy: 0.001)
        let assessment = ScoringEngine.assess(summary)
        // Every attempt is evidence — dropping uncleared floors would let a player cherry
        // -pick their easiest results — but only cleared floors count towards progression.
        XCTAssertEqual(assessment.totalItems, 8)
        XCTAssertEqual(assessment.levelsCleared, 1)
    }

    func testHeadlineQuotesTheEstimateAndIsNotEmpty() {
        for run in [self.strongRun(), self.weakRun()] {
            let assessment = ScoringEngine.assess(run)
            XCTAssertGreaterThan(assessment.headline.count, 40)
            XCTAssertTrue(
                assessment.headline.contains(String(Int(assessment.iqEstimate.rounded()))),
                "headline should quote the estimate it is describing"
            )
        }
    }

    func testReliabilityNoteReflectsTheEvidenceAvailable() {
        let tiny = ScoringEngine.assess(RunSummary(levelResults: [self.levelResult(1, items: [
            self.item(), self.item(),
        ])]))
        XCTAssertTrue(tiny.reliabilityNote.contains("rough guide"))
    }

    func testLevelBreakdownIsOrderedAndComplete() {
        let summary = RunSummary(levelResults: [
            self.levelResult(3, items: [self.item(level: 3)]),
            self.levelResult(1, items: [self.item(level: 1)]),
        ])
        let breakdown = ScoringEngine.assess(summary).levelBreakdown
        XCTAssertEqual(breakdown.map(\.levelID), [1, 3])
        XCTAssertEqual(breakdown.first?.name, LevelCatalog.level(1)?.name)
    }
}

final class CoachingEngineTests: XCTestCase {
    func testEveryDomainHasCompleteSpecificAdvice() {
        for domain in CognitiveDomain.allCases {
            let advice = CoachingEngine.knowledge(for: domain)
            XCTAssertGreaterThan(advice.technique.count, 80, "\(domain) technique is too thin")
            XCTAssertGreaterThan(advice.drill.count, 80, "\(domain) drill is too thin")
            XCTAssertGreaterThan(advice.pitfall.count, 40, "\(domain) pitfall is too thin")
        }
    }

    func testNoAdviceContainsGenericFiller() {
        // The whole point of this engine is that advice is never "just do more puzzles".
        let banned = ["do more puzzles", "practise more", "keep trying", "good job", "try harder"]
        for domain in CognitiveDomain.allCases {
            let advice = CoachingEngine.knowledge(for: domain)
            for phrase in banned {
                for field in [advice.technique, advice.drill, advice.pitfall] {
                    XCTAssertFalse(
                        field.lowercased().contains(phrase),
                        "\(domain) advice contains generic filler: \(phrase)"
                    )
                }
            }
        }
    }

    func testEachClusterTagHasItsOwnTechnique() {
        let tags = [
            "alternating-difference", "quadratic", "rotation-angle", "mirror-handedness",
            "fold-symmetry", "truth-statement", "echo-span", "grid-position",
            "matrix-rule", "percent-change", "work-rate", "probability-space", "spatial-count",
        ]
var seenTechniques = Set<String>()
        var seenPitfalls = Set<String>()
        for tag in tags {
            let advice = CoachingEngine.clusterTechnique(tag, domain: .pattern)
            XCTAssertTrue(seenTechniques.insert(advice).inserted, "tag \(tag) reuses another tag's technique")
            XCTAssertGreaterThan(advice.count, 60)

            let pitfall = CoachingEngine.clusterPitfall(tag)
            XCTAssertTrue(seenPitfalls.insert(pitfall).inserted, "tag \(tag) reuses another tag's pitfall")
            XCTAssertGreaterThan(pitfall.count, 30)

            XCTAssertFalse(CoachingEngine.label(for: tag).isEmpty)
            XCTAssertTrue(
                !CoachingEngine.label(for: tag).contains("_"),
                "tag \(tag) label should be human readable"
            )
        }
    }

    func testSuggestedLevelIsTheHighestFloorExercisingTheDomain() {
        XCTAssertEqual(CoachingEngine.suggestedLevel(for: .memory), 5)
        XCTAssertEqual(CoachingEngine.suggestedLevel(for: .spatial), 6)
        XCTAssertEqual(CoachingEngine.suggestedLevel(for: .speed), nil)
    }

    func testTipsAreEmptyWithoutEvidence() {
        XCTAssertTrue(CoachingEngine.tips(for: .empty).isEmpty)
    }

    func testNoDomainAppearsOnTwoCards() {
        // The same weakness explained twice in different words is worse than once.
        var items: [ItemResult] = []
        for index in 0..<40 {
            items.append(ItemResult(
                id: "\(index)", levelID: 6, kind: .rotation, domain: .spatial, theta: 3.0,
                skillTag: "rotation-angle", correct: index.isMultiple(of: 6),
                elapsed: 20, timeLimit: 28, hintsUsed: 1
            ))
        }
        let tips = CoachingEngine.tips(for: ScoringEngine.assess(
            RunSummary(levelResults: [LevelResult(id: "L6", levelID: 6, items: items, stars: 1, score: 90, bestStreak: 2)])
        ))
        let domains = tips.map(\.domain)
        XCTAssertEqual(domains.count, Set(domains).count, "a domain is reported on more than one card")
    }

    func testEvidenceUsesSingularFloorForASingleFloor() {
        var items: [ItemResult] = []
        for index in 0..<20 {
            items.append(ItemResult(
                id: "\(index)", levelID: 5, kind: .memorySequence, domain: .memory, theta: 2.6,
                skillTag: "echo-span", correct: index.isMultiple(of: 4),
                elapsed: 18, timeLimit: 26, hintsUsed: 0
            ))
        }
        let tips = CoachingEngine.tips(for: ScoringEngine.assess(
            RunSummary(levelResults: [LevelResult(id: "L5", levelID: 5, items: items, stars: 1, score: 90, bestStreak: 2)])
        ))
        let cluster = tips.first { $0.kind == .errorCluster }
        XCTAssertNotNil(cluster)
        XCTAssertTrue(cluster!.evidence.contains("floor 5"), cluster!.evidence)
        XCTAssertFalse(cluster!.evidence.contains("floors 5"), cluster!.evidence)
    }

    func testEvidenceQuotesActualNumbers() {
        let items = (0..<30).map { index in
            ItemResult(
                id: "\(index)", levelID: 6, kind: .rotation, domain: .spatial, theta: 3.4,
                skillTag: "rotation-angle", correct: index.isMultiple(of: 5),
                elapsed: 18, timeLimit: 28, hintsUsed: 0
            )
        }
        let assessment = ScoringEngine.assess(RunSummary(levelResults: [
            LevelResult(id: "L6", levelID: 6, items: items, stars: 1, score: 200, bestStreak: 2),
        ]))
        let tips = CoachingEngine.tips(for: assessment)
        XCTAssertFalse(tips.isEmpty)
        let digits = CharacterSet.decimalDigits
        for tip in tips {
            XCTAssertGreaterThan(
                tip.evidence.unicodeScalars.filter { digits.contains($0) }.count, 0,
                "evidence must quote a number, got: \(tip.evidence)"
            )
        }
    }
}

final class LevelCatalogTests: XCTestCase {
    func testThereAreExactlyTenLevels() {
        XCTAssertEqual(LevelCatalog.count, 10)
        XCTAssertEqual(LevelCatalog.all.map(\.id), Array(1...10))
        XCTAssertEqual(LevelCatalog.finalLevelID, 10)
    }

    func testDifficultyRisesMonotonicallyFloorByFloor() {
        var previousOpening = -1.0
        for level in LevelCatalog.all {
            XCTAssertGreaterThanOrEqual(level.openingTheta, previousOpening - 0.001,
                                        "floor \(level.id) starts easier than the floor before it")
            previousOpening = level.openingTheta
            XCTAssertGreaterThan(level.closingTheta, level.openingTheta,
                                 "floor \(level.id) does not ramp")
        }
    }

    func testPerItemLimitLeavesHeadroom() {
        for level in LevelCatalog.all {
            XCTAssertLessThan(level.perItemLimit, level.duration, "floor \(level.id)")
            XCTAssertGreaterThan(level.perItemLimit, 5, "floor \(level.id) is unplayably short per item")
        }
    }

    func testEveryLevelHasHintsAndAtLeastFiveItems() {
        for level in LevelCatalog.all {
            XCTAssertGreaterThanOrEqual(level.itemCount, 5, "floor \(level.id)")
            XCTAssertGreaterThanOrEqual(level.hintCharges, 2, "floor \(level.id) is too stingy with hints")
            XCTAssertFalse(level.puzzleKinds.isEmpty)
        }
    }

    func testStarGateRisesWithAltitude() {
        var previous = 0.0
        for level in LevelCatalog.all {
            XCTAssertGreaterThan(level.starGate, previous)
            previous = level.starGate
        }
        XCTAssertLessThanOrEqual(LevelCatalog.all.last!.starGate, 1.0)
    }

    func testEveryPuzzleKindIsReachableSomewhere() {
        let reachable = Set(LevelCatalog.all.flatMap(\.puzzleKinds))
        XCTAssertEqual(reachable, Set(PuzzleKind.allCases))
    }

    func testFactoryProducesTheRightNumberOfItemsWithARisingRamp() {
        for level in LevelCatalog.all {
            let puzzles = PuzzleFactory.puzzles(for: level, seed: 12_345)
            XCTAssertEqual(puzzles.count, level.itemCount, "floor \(level.id)")
            let thetas = puzzles.map(\.theta)
            XCTAssertEqual(thetas, thetas.sorted(), "floor \(level.id) items must get harder in order")
            XCTAssertEqual(puzzles.map(\.id).count, Set(puzzles.map(\.id)).count,
                           "floor \(level.id) produced duplicate item ids")
            XCTAssertTrue(Set(puzzles.map(\.kind)).isSubset(of: Set(level.puzzleKinds)),
                          "floor \(level.id) used a kind it does not host")
        }
    }

    func testAdaptiveFloorsBendTowardsThePlayerButNeverEasier() {
        let adaptive = LevelCatalog.all.filter(\.isAdaptive)
        XCTAssertFalse(adaptive.isEmpty, "the adaptive floors are the interesting ones — keep them")
        for level in adaptive {
            let baseline = PuzzleFactory.puzzles(for: level, seed: 7)
            let easier = PuzzleFactory.puzzles(for: level, seed: 7, abilityOverride: 1.0)
            let harder = PuzzleFactory.puzzles(for: level, seed: 7, abilityOverride: 4.5)

            let meanBaseline = baseline.map(\.theta).reduce(0, +) / Double(baseline.count)
            let meanHarder = harder.map(\.theta).reduce(0, +) / Double(harder.count)
            let meanEasier = easier.map(\.theta).reduce(0, +) / Double(easier.count)

            XCTAssertGreaterThanOrEqual(meanHarder, meanBaseline, "floor \(level.id) ignored a strong player")
            XCTAssertLessThan(meanEasier, meanBaseline, "floor \(level.id) ignored a weak player")
        }
    }

    func testSeedsReproduceARun() {
        for level in LevelCatalog.all {
            let a = PuzzleFactory.puzzles(for: level, seed: 99)
            let b = PuzzleFactory.puzzles(for: level, seed: 99)
            XCTAssertEqual(a.map(\.answer), b.map(\.answer), "floor \(level.id)")
            XCTAssertEqual(a.map(\.stimulus), b.map(\.stimulus), "floor \(level.id)")
        }
    }

    func testKindDomainMappingIsComplete() {
        for kind in PuzzleKind.allCases {
            XCTAssertTrue(CognitiveDomain.allCases.contains(kind.domain), "\(kind)")
            XCTAssertGreaterThanOrEqual(kind.maxTheta, kind.minTheta, "\(kind)")
        }
    }
}
final class StarRulesTests: XCTestCase {
    private let level = LevelCatalog.level(1)!

    private func items(correctCount: Int, of total: Int, elapsedRatio: Double) -> [ItemResult] {
        (0..<total).map { index in
            ItemResult(
                id: "\(index)", levelID: self.level.id, kind: .sequence, domain: .pattern,
                theta: 2.0, skillTag: "arithmetic-step",
                correct: index < correctCount,
                elapsed: 30 * elapsedRatio, timeLimit: 30, hintsUsed: 0
            )
        }
    }

    private func stars(correctCount: Int, of total: Int, elapsedRatio: Double) -> Int {
        StarRules.evaluate(
            items: self.items(correctCount: correctCount, of: total, elapsedRatio: elapsedRatio),
            level: self.level, score: 0, bestStreak: 0
        ).stars
    }

    func testEmptyRunScoresNothing() {
        let result = StarRules.evaluate(items: [], level: self.level, score: 0, bestStreak: 0)
        XCTAssertEqual(result.stars, 0)
        XCTAssertFalse(result.isCleared)
    }

    func testNothingClearsBelowTheFloorGate() {
        // Floor 1's gate is 0.60, so 2 of 5 is not enough.
        XCTAssertEqual(self.stars(correctCount: 2, of: 5, elapsedRatio: 0.2), 0)
    }

    func testTheGateUnlocksTheFloor() {
        XCTAssertEqual(self.stars(correctCount: 3, of: 5, elapsedRatio: 0.2), 1)
    }

    func testTwoStarsAtSeventyFivePercent() {
        XCTAssertEqual(self.stars(correctCount: 4, of: 5, elapsedRatio: 0.2), 2)
    }

    func testThreeStarsNeedAccuracyAndPaceTogether() {
        // Fast and accurate gets three; accurate but slow only gets two.
        XCTAssertEqual(self.stars(correctCount: 5, of: 5, elapsedRatio: 0.2), 3)
        XCTAssertEqual(self.stars(correctCount: 5, of: 5, elapsedRatio: 0.9), 2)
    }

    func testThreeStarsCannotBeBoughtWithSpeedAlone() {
        XCTAssertEqual(self.stars(correctCount: 3, of: 5, elapsedRatio: 0.05), 1)
    }

    func testClockLeftIsClampedSoTimeoutsCannotEarnPace() {
        let result = StarRules.evaluate(
            items: self.items(correctCount: 5, of: 5, elapsedRatio: 3.0),
            level: self.level, score: 0, bestStreak: 0
        )
        XCTAssertEqual(result.stars, 2, "overrunning the clock must not count as time remaining")
    }

    func testEveryFloorIsClearableAndGateIsReachable() {
        for level in LevelCatalog.all {
            let needed = Int((level.starGate * Double(level.itemCount)).rounded(.up))
            let result = StarRules.evaluate(
                items: (0..<level.itemCount).map { index in
                    ItemResult(
                        id: "\(index)", levelID: level.id, kind: .sequence, domain: .pattern,
                        theta: 2.0, skillTag: "t", correct: index < needed,
                        elapsed: 5, timeLimit: level.perItemLimit, hintsUsed: 0
                    )
                },
                level: level, score: 0, bestStreak: 0
            )
            XCTAssertTrue(result.isCleared, "floor \(level.id) is unclearable at its own gate")
        }
    }
}
