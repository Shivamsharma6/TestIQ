import Foundation
import SwiftUI

/// Orchestrates one attempt at one floor.
///
/// Timing, the streak multiplier, hint accounting and the memory-presentation clock all
/// live here. The view layer renders what this exposes and calls back in; no game rule is
/// decided in a view.
@MainActor
@Observable
final class GameViewModel {
    enum Phase: Equatable {
        /// Sequential flash for an echo item.
        case presenting(step: Int, total: Int)
        /// Everything lit at once for a grid item.
        case presentingAll
        /// The player is answering.
        case awaitingAnswer
        case showingFeedback(correct: Bool)
        case finished
    }

    // MARK: - Inputs

    let level: LevelDefinition
    let abilityUsed: Double?
    private(set) var puzzles: [Puzzle]
    private(set) var index = 0
    private(set) var result: LevelResult?

    // MARK: - Run state

    private(set) var phase: Phase = .awaitingAnswer
    private(set) var itemStartedAt = Date()
    private(set) var timeRemaining: TimeInterval
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var score = 0
    private(set) var hintsRemaining: Int
    private(set) var hintsUsedOnCurrentItem = 0
    private(set) var showHint = false
    private(set) var lastAnswerCorrect: Bool?

    // Draft answers for the non-choice archetypes.
    private(set) var selectedOptionIndex: Int?
    private(set) var tappedIndices: [Int] = []
    private(set) var chosenOrder: [Int] = []
    private(set) var submittedLetters: [String] = []
    private(set) var usedTileIndices: Set<Int> = []

    /// Bumped on each answer so the view can fire a one-shot effect exactly once.
    private(set) var burstToken = 0
    private(set) var shakeToken = 0

    private var items: [ItemResult] = []
    private var clock: Timer?
    private var presentation: Task<Void, Never>?

    // MARK: - Derived

    var puzzle: Puzzle { self.puzzles[min(self.index, self.puzzles.count - 1)] }
    var progress: Double { self.puzzles.isEmpty ? 0 : Double(self.index) / Double(self.puzzles.count) }
    var isLastItem: Bool { self.index >= self.puzzles.count - 1 }
    var comboMultiplier: Int { min(5, max(1, self.streak)) }
    var timeFraction: Double {
        guard self.puzzle.timeLimit > 0 else { return 0 }
        return max(0, min(1, self.timeRemaining / self.puzzle.timeLimit))
    }
    var summaryLine: String { "Item \(min(self.index + 1, self.puzzles.count)) of \(self.puzzles.count)" }
    var canUndo: Bool { !self.tappedIndices.isEmpty || !self.submittedLetters.isEmpty || !self.chosenOrder.isEmpty }
    var isEcho: Bool { self.puzzle.kind == .memorySequence }
    var isGridRecall: Bool { self.puzzle.kind == .gridRecall }

    var memoryPhase: MemoryGridView.Phase {
        switch self.phase {
        case .presenting(let step, let total): return .presenting(step: step, total: total)
        case .presentingAll: return .presentingAll
        default: return .collecting
        }
    }

    init(level: LevelDefinition, attempt: Int, ability: Double?) {
        self.level = level
        self.abilityUsed = level.isAdaptive ? ability : nil
        self.timeRemaining = level.perItemLimit
        self.hintsRemaining = level.hintCharges
        // A different salt per attempt keeps replays fresh while the seed stays
        // reproducible, which is what lets a level be resumed identically after a crash.
        self.puzzles = PuzzleFactory.puzzles(
            for: level,
            seed: PuzzleFactory.seed(for: level.id, attempt: attempt, sessionSalt: UInt64.random(in: 0...UInt64.max)),
            abilityOverride: level.isAdaptive ? ability : nil
        )
    }

    // MARK: - Lifecycle

    func start() {
        HapticsEngine.shared.prepare()
        self.beginCurrentItem()
    }

    func stop() {
        self.clock?.invalidate()
        self.clock = nil
        self.presentation?.cancel()
        self.presentation = nil
    }

    private func beginCurrentItem() {
        self.itemStartedAt = Date()
        self.timeRemaining = self.puzzle.timeLimit
        self.hintsUsedOnCurrentItem = 0
        self.showHint = false
        self.selectedOptionIndex = nil
        self.tappedIndices = []
        self.chosenOrder = []
        self.submittedLetters = []
        self.usedTileIndices = []
        self.lastAnswerCorrect = nil

        if self.isEcho || self.isGridRecall {
            self.runMemoryPresentation()
        } else {
            self.phase = .awaitingAnswer
            self.startClock()
        }
    }

    // MARK: - Clock

    private func startClock() {
        self.clock?.invalidate()
        let limit = self.puzzle.timeLimit
        let startedAt = self.itemStartedAt
        var lastBeep = Int(limit)

        // Elapsed time is recomputed from the wall clock on every tick rather than
        // decremented, so a backgrounded app, a dropped frame or a run-loop pause can
        // never make the timer drift.
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, self.phase == .awaitingAnswer else {
                    timer.invalidate()
                    return
                }
                self.timeRemaining = max(0, limit - Date().timeIntervalSince(startedAt))
                let whole = Int(ceil(self.timeRemaining))
                if whole <= 5, whole != lastBeep, whole > 0 {
                    lastBeep = whole
                    SoundEngine.shared.countdownTick(urgent: whole <= 3)
                    HapticsEngine.shared.timeWarning()
                }
                if self.timeRemaining <= 0 {
                    timer.invalidate()
                    self.submit(timedOut: true)
                }
            }
        }
        // `.common` keeps the clock running while a scroll view is being dragged.
        RunLoop.main.add(timer, forMode: .common)
        self.clock = timer
    }

    // MARK: - Memory presentation

    private func runMemoryPresentation() {
        self.phase = self.isEcho ? .presenting(step: 0, total: 1) : .presentingAll
        self.presentation?.cancel()

        guard case .memory(let spec) = self.puzzle.stimulus else {
            self.phase = .awaitingAnswer
            self.startClock()
            return
        }

        if self.isGridRecall {
            // Grid items light everything simultaneously, so there is no sequence to walk.
            let hold = spec.lit.count >= 5 ? 1.05 : 0.85
            SoundEngine.shared.selection()
            self.presentation = Task { [weak self] in
                try? await Task.sleep(for: .seconds(hold))
                self?.finishPresentation()
            }
            return
        }

        let indices = spec.sequence
        self.phase = .presenting(step: -1, total: indices.count)
        self.presentation = Task { [weak self] in
            for (offset, _) in indices.enumerated() {
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self, case .presenting = self.phase else { return }
                    self.phase = .presenting(step: offset, total: indices.count)
                }
                SoundEngine.shared.selection()
                try? await Task.sleep(for: .milliseconds(460))
                await MainActor.run { [weak self] in
                    guard let self, case .presenting = self.phase else { return }
                    self.phase = .presenting(step: -1, total: indices.count)
                }
                try? await Task.sleep(for: .milliseconds(210))
            }
            self?.finishPresentation()
        }
    }

    private func finishPresentation() {
        // Accept either presenting phase. (An earlier `guard case .presenting ..., case
        // .presentingAll ...` could never both be true, which silently left every memory
        // item stuck on the presentation screen with no way to answer.)
        switch self.phase {
        case .presenting, .presentingAll: break
        default: return
        }
        self.phase = .awaitingAnswer
        // The answering window starts when the flashes stop rather than when the
        // presentation began, so a long sequence still leaves enough time to answer it.
        self.itemStartedAt = Date()
        self.startClock()
    }

    // MARK: - Interaction

    func choose(option index: Int) {
        guard self.phase == .awaitingAnswer, self.selectedOptionIndex == nil else { return }
        self.selectedOptionIndex = index
        self.submit(timedOut: false)
    }

    func tap(tile index: Int) {
        guard self.phase == .awaitingAnswer, !self.tappedIndices.contains(index) else { return }
        guard case .tapSequence(let expected) = self.puzzle.answer else { return }
        self.tappedIndices.append(index)
        HapticsEngine.shared.tick()

        if self.isGridRecall {
            // Order does not matter here, so the only commitment point is a full set.
            if self.tappedIndices.count == expected.count { self.submit(timedOut: false) }
        } else {
            // Echo is strictly serial: one wrong tap ends the item, because continuing
            // after a mistake measures nothing.
            let prefix = Array(expected.prefix(self.tappedIndices.count))
            if self.tappedIndices != prefix { self.submit(timedOut: false) }
        }
    }

    func undoLastTap() {
        guard self.phase == .awaitingAnswer else { return }
        if !self.tappedIndices.isEmpty {
            self.tappedIndices.removeLast()
        } else if let last = self.submittedLetters.popLast() {
            if let index = self.puzzle.tiles.lastIndex(of: last) { self.usedTileIndices.remove(index) }
        } else if !self.chosenOrder.isEmpty {
            self.chosenOrder.removeLast()
        }
    }

    func tapOrder(labelIndex: Int) {
        guard self.phase == .awaitingAnswer else { return }
        // Tapping the most recent entry removes it, so the tap target stays large and the
        // player never needs a small "back" affordance on this interaction.
        if let existing = self.chosenOrder.lastIndex(of: labelIndex) {
            self.chosenOrder.remove(at: existing)
            HapticsEngine.shared.tick()
            return
        }
        guard !self.chosenOrder.contains(labelIndex) else { return }
        self.chosenOrder.append(labelIndex)
        HapticsEngine.shared.tick()
        if self.chosenOrder.count == self.puzzle.orderLabels.count {
            self.submit(timedOut: false)
        }
    }

    func tapTile(_ index: Int) {
        guard self.phase == .awaitingAnswer, index < self.puzzle.tiles.count else { return }
        guard !self.usedTileIndices.contains(index) else { return }
        self.usedTileIndices.insert(index)
        self.submittedLetters.append(self.puzzle.tiles[index])
        HapticsEngine.shared.tick()
        // The last tile is the only commitment point, so a half-built word can always be
        // corrected without penalty.
        if self.submittedLetters.count == self.puzzle.tiles.count {
            self.submit(timedOut: false)
        }
    }

    func useHint() {
        guard self.phase == .awaitingAnswer, self.hintsRemaining > 0, !self.showHint else { return }
        self.hintsRemaining -= 1
        self.hintsUsedOnCurrentItem += 1
        self.showHint = true
        SoundEngine.shared.hint()
        HapticsEngine.shared.tick()
    }

    // MARK: - Submission

    private func submit(timedOut: Bool) {
        guard self.phase == .awaitingAnswer else { return }
        self.clock?.invalidate()
        self.clock = nil

        let rawElapsed = Date().timeIntervalSince(self.itemStartedAt)
        let elapsed = min(rawElapsed, self.puzzle.timeLimit * 1.5)
        let correct = !timedOut && self.currentAnswerMatches()

        self.items.append(
            ItemResult(
                id: self.puzzle.id,
                levelID: self.level.id,
                kind: self.puzzle.kind,
                domain: self.puzzle.domain,
                theta: self.puzzle.theta,
                skillTag: self.puzzle.skillTag,
                correct: correct,
                // A timeout is recorded as the full allowance consumed, so abandoning an
                // item costs exactly as much as running the clock out on it.
                elapsed: timedOut ? self.puzzle.timeLimit : elapsed,
                timeLimit: self.puzzle.timeLimit,
                hintsUsed: self.hintsUsedOnCurrentItem,
                timedOut: timedOut
            )
        )

        if correct {
            self.streak += 1
            self.bestStreak = max(self.bestStreak, self.streak)
            // A hint costs a third of the item's face value, so a hinted answer is never
            // better than a clean one — which is what makes using one a real trade-off.
            let hintFactor = self.hintsUsedOnCurrentItem > 0
                ? max(0.4, 1.0 - 0.3 * Double(self.hintsUsedOnCurrentItem)) : 1.0
            let speedFactor = max(0.4, 1.0 - 0.5 * (elapsed / max(self.puzzle.timeLimit, 1)))
            self.score += Int((100 * Double(self.comboMultiplier) * hintFactor * speedFactor).rounded())
            HapticsEngine.shared.correctWithStreak(self.streak)
            SoundEngine.shared.correct(streak: self.streak)
            self.burstToken += 1
        } else {
            self.streak = 0
            HapticsEngine.shared.wrong()
            SoundEngine.shared.wrong()
            self.shakeToken += 1
        }

        self.lastAnswerCorrect = correct
        self.phase = .showingFeedback(correct: correct)
    }

    private func currentAnswerMatches() -> Bool {
        switch self.puzzle.answer {
        case .optionIndex(let expected):
            return self.selectedOptionIndex == expected
        case .tapSequence(let expected):
            return self.tappedIndices == expected
        case .ordering(let expected):
            return self.chosenOrder == expected
        case .word(let expected):
            return self.submittedLetters.joined() == expected
        }
    }

    /// Advances past the feedback beat, kept separate from `submit` so the player always
    /// sees the outcome before the next item arrives.
    func advance() {
        guard case .showingFeedback = self.phase else { return }
        if self.isLastItem {
            self.finish()
        } else {
            self.index += 1
            self.beginCurrentItem()
        }
    }

    private func finish() {
        self.stop()
        let result = StarRules.evaluate(
            items: self.items, level: self.level, score: self.score, bestStreak: self.bestStreak
        )
        self.result = result
        self.phase = .finished
        if result.isCleared {
            HapticsEngine.shared.levelCleared()
            SoundEngine.shared.levelCleared()
        } else {
            HapticsEngine.shared.failure()
        }
    }

    // MARK: - Feedback helpers

    var correctOptionIndex: Int? {
        guard case .optionIndex(let expected) = self.puzzle.answer else { return nil }
        return expected
    }

    var expectedWord: String? {
        guard case .word(let word) = self.puzzle.answer else { return nil }
        return word
    }
}
