import Foundation

/// Builds the "how to improve, and how not to" section of the report.
///
/// The rule this file exists to enforce: **no tip may be generic.** Every card is
/// triggered by a specific observation, quotes the numbers behind it, names a technique
/// that applies to that exact failure mode, gives a drill someone could perform today,
/// and states the mistake that keeps the weakness alive.
public enum CoachingEngine {
    public static func tips(for assessment: Assessment) -> [CoachingTip] {
        guard assessment.totalItems > 0 else { return [] }
        let clusters = self.errorClusterTips(assessment)
        // An error-cluster card is strictly more specific than a domain card, so a domain
        // that already has one is dropped rather than shown twice in near-identical words.
        let covered = Set(clusters.map(\.domain))
        var tips = self.domainWeaknessTips(assessment, excluding: covered)
        tips += clusters
        if let pacing = self.pacingTip(assessment) { tips.append(pacing) }
        return self.deduplicated(tips)
    }

    // MARK: - Domain weakness

    private static func domainWeaknessTips(
        _ assessment: Assessment, excluding covered: Set<CognitiveDomain> = []
    ) -> [CoachingTip] {
        assessment.growthAreas.compactMap { score in
            guard !covered.contains(score.domain) else { return nil }
            let knowledge = self.knowledge(for: score.domain)
            let gap = assessment.compositeTheta - score.theta
            let replay = self.suggestedLevel(for: score.domain)
            let itemWord = score.itemCount == 1 ? "item" : "items"
            let gapText = String(format: "%.2f", gap)

            let evidence: String
            if score.itemCount == 0 {
                evidence = score.domain.title
                    + " had no direct items — this axis is inferred from your speed profile."
            } else {
                evidence = "On " + score.domain.title
                    + " you indexed " + String(Int(score.index)) + "/100 across "
                    + String(score.itemCount) + " " + itemWord + " — " + gapText
                    + " below your composite of " + String(Int(assessment.iqEstimate)) + " IQ points. "
                    + score.domain.blurb
            }

            return CoachingTip(
                id: UUID(),
                kind: .domainWeakness,
                title: "Lift your \(score.domain.shortTitle.lowercased()) ceiling",
                evidence: evidence,
                technique: knowledge.technique,
                drill: knowledge.drill,
                pitfall: knowledge.pitfall,
                domain: score.domain,
                suggestedLevelID: replay
            )
        }
    }

    // MARK: - Error clusters

    private static func errorClusterTips(_ assessment: Assessment) -> [CoachingTip] {
        // One cluster per domain, so a player with a shaky floor does not receive four
        // variations of the same advice.
        var seenDomains = Set<CognitiveDomain>()

        return assessment.errorClusters.compactMap { cluster in
            guard !seenDomains.contains(cluster.domain) else { return nil }
            seenDomains.insert(cluster.domain)

            let label = self.label(for: cluster.tag)
            let floors = cluster.levelIDs.map(String.init).sorted { Int($0)! < Int($1)! }
            let where_ = floors.count == 1
                ? "floor \(floors[0])"
                : "floors " + floors.joined(separator: ", ")
            let evidence = "You missed \(cluster.count) \(label) \(cluster.count == 1 ? "item" : "items") on "
                + where_ + ". That is a specific, repeating error rather than general difficulty."

            return CoachingTip(
                id: UUID(),
                kind: .errorCluster,
                title: "Stop repeating: \(label)",
                evidence: evidence,
                technique: self.clusterTechnique(cluster.tag, domain: cluster.domain),
                drill: self.clusterDrill(cluster.kind, domain: cluster.domain),
                pitfall: self.clusterPitfall(cluster.tag),
                domain: cluster.domain,
                suggestedLevelID: cluster.levelIDs.last
            )
        }
    }

    // MARK: - Pacing

    private static func pacingTip(_ assessment: Assessment) -> CoachingTip? {
        guard let speed = assessment.domainScore(.speed), speed.itemCount >= 6 else { return nil }
        guard speed.medianLatencyRatio > 0.62, assessment.overallAccuracy < 0.8 else { return nil }

        return CoachingTip(
            id: UUID(),
            kind: .pacing,
            title: "Your accuracy is losing to your clock",
            evidence: "Correct answers consumed \(Int(speed.medianLatencyRatio * 100))% of the available time on average, while your overall accuracy sat at \(Int(assessment.overallAccuracy * 100))%. Speed and accuracy are both suffering, which is the signature of deliberating too long rather than not knowing.",
            technique: "Commit-then-check. Give an item a hard internal deadline of about 60% of the allowance. If nothing clicks by then, pick your best-supported option and move on — the item is already banked as either a gain or a small loss, whereas hesitation wastes the whole allowance.",
            drill: "Replay any floor at 70% speed. Answer everything, including the ones you are unsure about, the moment a plausible option appears. Track how many slow items were actually wrong: if few were, the hesitation was costing you points for nothing.",
            pitfall: "Do not treat the timer as a measure of worth. An item you solve on the last second is worth the same as one you solve instantly, because the scoring only rewards speed as a modest bonus on top of correctness.",
            domain: .speed,
            suggestedLevelID: assessment.levelBreakdown
                .filter { $0.accuracy < assessment.overallAccuracy }
                .map(\.levelID).last
        )
    }

    // MARK: - Knowledge base

    struct Knowledge {
        let technique: String
        let drill: String
        let pitfall: String
    }

    static func knowledge(for domain: CognitiveDomain) -> Knowledge {
        switch domain {
        case .pattern:
            return Knowledge(
                technique: "Difference ladder. Write the first differences on a separate line beneath the sequence, then look for a pattern in the differences themselves. If the differences alternate, ladder it a second time. Only after the second difference looks clean should you extrapolate.",
                drill: "Fifteen minutes, three rounds of five. Take any number sequence you can find, and for each one commit to writing the difference ladder before you consider any answer. Mark the round where you skipped straight to extrapolating — that round is the one to repeat tomorrow.",
                pitfall: "Do not guess the next number from the shape of the run. A sequence that looks quadratic from far away is often two interleaved arithmetic sequences, and eyeballing the curvature is what produces confident, wrong answers."
            )
        case .verbal:
            return Knowledge(
                technique: "Letter algebra. Convert each letter to its alphabet position, treat the rule as an equation, then convert back. When a puzzle is about letter counts or positions, state the property you are tracking out loud before you test options.",
                drill: "Twenty word-rebuilds, spelling each answer silently before committing. Then five letter-algebra items, writing the numeric mapping A=1…Z=26 at the top of the page and keeping it visible. Speed comes from having the mapping written down, not from having it memorised.",
                pitfall: "Do not check a rebuilt word only for being a real word. The distractor words are all real words; that is exactly why they are there."
            )
        case .logic:
            return Knowledge(
                technique: "Assign, then eliminate. Pick the statement or item you are most confident about, commit to its consequence, and use it to remove one option from every other row. Only reason about the remaining options once elimination has narrowed them.",
                drill: "Three constrained-ordering puzzles and three truth-or-lie puzzles, written on paper. For each, do a full pass of pure elimination before allowing yourself to consider any answer directly. Notice which single fact did the most work — that is the one to look for first next time.",
                pitfall: "Do not start from a statement you have not yet checked and build a whole scenario on it. One wrong premise poisons every step after it, and there is usually a statement you can verify outright."
            )
        case .memory:
            return Knowledge(
                technique: "Chunk it. Group items into meaningful units rather than holding each one separately — three letters as one syllable, or a shape grid as three rows. Chunks shrink the number of things you are actively holding.",
                drill: "Span laddering, three sessions a week. Recall an echo sequence one step longer than you managed last time, and stop the session the moment you fail twice at the same length. Write the length down; the number going up over two weeks is the real metric.",
                pitfall: "Do not rehearse by re-watching the flashing sequence. That measures your ability to pay attention to a repeat, which is not the ability being tested."
            )
        case .spatial:
            return Knowledge(
                technique: "Anchor and rotate. Pick one distinctive feature — a corner, an arrowhead, a notch — name it in words, then track only where that feature ends up. Mentally turning the whole figure at once loses you the detail you are using to orient.",
                drill: "Ten rotation items and ten mirror items. Before answering each, say the anchor's starting position out loud, then its ending position. For mirrors, remember that mirroring reverses handedness, so any shape with a definite left or right will come back as its opposite self.",
                pitfall: "Do not accept the first option that looks familiar. Rotation answers cluster in the same orientation, so the trap is usually a shape you have already seen rather than the right one."
            )
        case .abstract:
            return Knowledge(
                technique: "Test the simplest rule first. Before hunting for a pattern, try constant, then steps of one attribute, then two attributes moving independently. The right rule is almost always the one with the fewest moving parts.",
                drill: "Eight matrix items. For each, state your candidate rule as a single sentence before you look at the options — for example 'shape steps forward each cell in the row'. Then verify your sentence against all eight cells, not just the ones that led you to it.",
                pitfall: "Do not fill the missing cell by asking what looks balanced. The grid is decided by the cells you can see, and only those."
            )
        case .quantity:
            return Knowledge(
                technique: "Name the quantities before computing. Decide what one 'unit' is worth, convert every other number into that unit, and only then choose an operation. Work-rate problems collapse once both rates are expressed per hour.",
                drill: "Ten rate problems and ten ratio problems. On every one, write the unit conversion on the first line before any arithmetic. Then solve the same ten again tomorrow without looking — the second pass is what actually moves the number.",
                pitfall: "Do not reach for a percentage when the underlying relationship is a ratio, or the reverse. They look interchangeable and they are not; converting early is what keeps them straight."
            )
        case .speed:
            return Knowledge(
                technique: "Front-load recognition. Most lost time is spent deliberating between two options that were never going to feel obviously right. Decide your default answer for each option type up front, so deliberation only happens when the options genuinely differ.",
                drill: "One timed replay of any floor you have already completed. Aim to finish with at least 25% of the clock left, and afterwards check how many of your slowest answers were actually wrong. If the number is small, your hesitation is pure loss.",
                pitfall: "Do not trade accuracy for speed deliberately. The scoring adds a modest speed bonus on top of a correct answer and subtracts nothing extra for a fast wrong one, so guessing early is still a net loss."
            )
        }
    }

    static func label(for tag: String) -> String {
        switch tag {
        case "alternating-difference": return "alternating-difference sequence"
        case "quadratic": return "second-difference sequence"
        case "ratio-sequence": return "geometric sequence"
        case "prime-sequence": return "prime sequence"
        case "word-property": return "word-property odd-one-out"
        case "shape-property": return "shape-property odd-one-out"
        case "letter-shift": return "letter-shift item"
        case "anagram-scramble": return "scrambled word"
        case "truth-statement": return "truth-or-lie deduction"
        case "constraint-ordering": return "constrained ordering"
        case "echo-span": return "echo sequence"
        case "grid-position": return "grid recall"
        case "rotation-angle": return "mental rotation"
        case "mirror-handedness": return "mirror image"
        case "fold-symmetry": return "paper unfolding"
        case "spatial-count": return "overlapping shape count"
        case "matrix-rule": return "matrix rule"
        case "matrix-attribute": return "matrix attribute tracking"
        case "ratio-proportion": return "ratio item"
        case "percent-change": return "percentage change"
        case "work-rate": return "combined work rate"
        case "probability-space": return "probability sample space"
        case "mental-arithmetic": return "mental arithmetic"
        default: return tag.replacingOccurrences(of: "-", with: " ")
        }
    }

    static func clusterTechnique(_ tag: String, domain: CognitiveDomain) -> String {
        switch tag {
        case "alternating-difference":
            return "Alternating patterns must be read in two interleaved streams. Take the odd-positioned terms as one sequence and the even-positioned terms as another. Both are usually simple; the difficulty only appears when you insist on reading the whole run as one sequence."
        case "quadratic":
            return "Take one difference ladder. If the differences themselves step by a constant, the rule is second-order and the next term is the last difference plus the new step. A clean constant ladder is the only reliable signal here."
        case "rotation-angle":
            return "Anchor and rotate. Name one distinctive feature out loud — a corner, an arrowhead — then track only where that feature lands. Turning the whole figure at once loses the very detail you are using to orient yourself."
        case "mirror-handedness":
            return "Mirroring reverses handedness without changing the angle. Check the side that tells the shape apart: if the target has its flat edge on the left, the mirror has it on the right, and that single attribute is usually enough to choose."
        case "fold-symmetry":
            return "Work out how many layers the paper has at the punch point, then reflect every hole across each fold line going backwards through the folds. Reverse order matters: unfolding the last fold first is the only way the reflections stack correctly."
        case "truth-statement":
            return "Assign then eliminate. Commit to the one statement you can verify outright, draw its consequence for every person, and remove the options it kills before reasoning about anything else."
        case "echo-span":
            return "Chunk rather than itemise. Group the flashes into meaningful units of two or three and hold the chunks rather than the pieces. Recall is serial, so each extra tile costs disproportionately more than the same number of extra grid cells does."
        case "grid-position":
            return "Say each flash as a named position as it appears — 'top row, far left'. Verbal labels survive far longer than a mental image, and a grid recall failure is nearly always a labelling failure rather than a memory failure."
        case "matrix-rule", "matrix-attribute":
            return "Test the simplest rule first: constant, then one attribute stepping, then two attributes moving independently. State the rule as a single sentence and check it against every visible cell, not just the ones that produced it."
        case "percent-change":
            return "Identify the base before you compute. 'Increased by 20%' means 20% of the original, so the base is the starting value. Percent change from a new figure is the calculation that gets skipped and then missed."
        case "work-rate":
            return "Convert both rates to the same unit before adding them. Combined rate is the sum of rates, never the sum of times, and never the average of the two times."
        case "probability-space":
            return "Enumerate the sample space explicitly before dividing. Count the outcomes that satisfy the condition, count the outcomes in total, then divide those two numbers. Do not reason about the proportion directly."
        case "spatial-count":
            return "Sweep systematically rather than at random: left to right, top row first, counting each shape as its centre passes the vertical midline. Partial overlaps are where random counting loses shapes."
        case "mental-arithmetic":
            return "Round first, then correct. Get to a number you are sure of in one step, then apply the small adjustment. Forcing exact arithmetic on a hard sum under a clock is what causes the slip."
        default:
            return self.knowledge(for: domain).technique
        }
    }

    private static func clusterDrill(_ kind: PuzzleKind, domain: CognitiveDomain) -> String {
        let base = self.knowledge(for: domain).drill
        return "Replays help most when you know what you are watching for. Do this: replay the suggested floor, and before each \(kind.title.lowercased()) item, say the technique above out loud. \(base)"
    }

    static func clusterPitfall(_ tag: String) -> String {
        switch tag {
        case "alternating-difference":
            return "Do not read the whole run as one sequence. Interleaved runs look exactly like a single messy one until you split them by position."
        case "quadratic":
            return "Do not extrapolate the last two gaps. The second difference is what you need, and eyeballing the curvature of the run is how a confident wrong answer is produced."
        case "ratio-sequence":
            return "Do not treat a constant ratio as a constant difference, or the reverse. Check which one is actually constant before computing."
        case "prime-sequence":
            return "Do not assume the run is prime without testing, and do not count 1 as prime. Both mistakes produce an off-by-one at the end."
        case "rotation-angle":
            return "Do not track the whole figure at once. Rotating everything in your head loses the one detail you were using to orient yourself."
        case "mirror-handedness":
            return "Do not rotate when you should mirror. Mirroring preserves the angle and flips handedness; confusing the two looks plausible and is wrong every time."
        case "fold-symmetry":
            return "Do not unfold the folds in the order they were made. The reflections only stack correctly in reverse."
        case "truth-statement":
            return "Do not reason from a statement you have not yet checked. One false premise poisons every step after it."
        case "constraint-ordering":
            return "Do not start from the item you find most interesting. Start from the one you can place with certainty and let it order the rest."
        case "echo-span":
            return "Do not rehearse by re-watching the sequence. That measures attention to a repeat, which is not the ability being tested."
        case "grid-position":
            return "Do not go back over the flashes once they are gone, and do not hold a mental picture of the whole grid. Name the cells, not the image."
        case "matrix-rule", "matrix-attribute":
            return "Do not choose the option that makes the grid look finished. Only the eight visible cells decide the ninth."
        case "percent-change":
            return "Do not skip the step where you identify which value is the base. 'Increased by 20%' means 20% of the original — the base is nearly always the figure given first, and using the wrong one still produces a plausible number."
        case "ratio-proportion":
            return "Do not add or subtract ratio parts. They are not quantities; you must find one part first and only then scale it."
        case "work-rate":
            return "Do not add the two times, and do not average them. Combined rate is the sum of the rates, and the time is the reciprocal of that."
        case "probability-space":
            return "Do not reason about the proportion directly. Count the outcomes that satisfy the condition, count the total, and divide — skipping the enumeration is where the answer goes wrong."
        case "spatial-count":
            return "Do not count by looking harder. Counting needs a sweep order, and without one your eye skips overlapping shapes every time."
        default:
            return "Do not answer from recognition of how an answer looks. Work the rule through to the end, then choose."
        }
    }

    // MARK: - Helpers

    /// Best floor to replay for a given weakness: the highest *themed* floor built
    /// around it. The adaptive floors deliberately host every kind, so counting them
    /// would send the player to the finale for a spelling weakness.
    static func suggestedLevel(for domain: CognitiveDomain) -> Int? {
        LevelCatalog.all
            .filter { !$0.isAdaptive && $0.puzzleKinds.contains { $0.domain == domain } }
            .map(\.id)
            .max()
    }

    private static func deduplicated(_ tips: [CoachingTip]) -> [CoachingTip] {
        var seen = Set<String>()
        return tips.filter { seen.insert($0.title).inserted }
    }
}