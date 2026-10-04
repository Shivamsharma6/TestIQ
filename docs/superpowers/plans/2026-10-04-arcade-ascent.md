# Arcade Ascent Implementation Plan

> **For agentic workers:** Use subagent-driven-development with isolated file ownership. User approved the recommended direction; proceed through implementation and verification in this session.

**Goal:** Deliver an intuitive arcade ascent with meaningful personal competition, real attempt history, playful feedback, and visible skill practice.

**Architecture:** Pure Foundation progression values in Core feed the existing SwiftUI features. JSON saves migrate with optional new keys; AppState owns routing and the current round. Keep feedback and screen responsibilities separate so implementation can proceed concurrently without overlapping writes.

**Tech Stack:** Swift, SwiftUI, AVAudioEngine, UIKit feedback generators, XCTest through SwiftPM, Xcode iOS simulator.

## 1. Durable progress and integration (primary agent)

Files: Core/Model/PlayerProgress.swift, Core/Scoring/ProgressInsights.swift, Services/ProgressStore.swift, Services/AppState.swift, Tools/IQCoreTests/ProgressTests.swift.

- [x] Add failing tests for legacy JSON, history, duplicate IDs, latest/best separation, preserved stars/unlocks, and increasing attempt counters. Run `swift test --filter ProgressTests` to demonstrate absent behavior before implementation.
- [x] Move PlayerProgress into Core. Decode new `attemptHistory`, `earnedStars`, `personalBestScores`, and `learnedInteractions` keys with defaults. Maintain legacy keys and settings. Add mutating `record(_:)`, `latestResult(for:)`, and `personalBestScore(for:)`. Store only unique completed IDs. Legacy bests do not become fake history.
- [x] Add comparison tests, then ProgressInsights/PracticeTrend/PracticeMetrics. Split chronological floor history into earlier and recent disjoint windows of up to three rounds each; require four rounds. Match kind, half-step difficulty, and time allowance; require five matching items per window. Weight common strata equally so changing item mixtures cannot manufacture an accuracy gain.
- [x] AppState exposes `lastResult: LevelResult?`, `previousBestScore: Int?`, and `markInteractionLearned(_ key: String)`. Capture the prior record before saving. Guard start against locked floors. Recompute assessment after saving for current adaptation; use recent recorded rounds for coaching.
- [x] Run core tests and review persistence error paths. Preserve unreadable saves and expose save failures as recoverable UI state rather than deleting progress.

## 2. Home, intro, and completion (screen agent)

Files: Features/Home/*, Design/Theme.swift, optionally new Components/Arcade*.swift. Do not edit Game, Report, AppState, ProgressStore, or Core.

- [x] Replace long test framing with a prominent next-challenge card, current ascent rewards, personal-best framing, and an accessible map below. Keep settings usable.
- [x] Make intro concise and actionable; remove internal theta values and unsupported adaptation claims. Show a personal record when present.
- [x] Completion reads `app.lastResult ?? app.progress.latestResult(for: levelID)`, never substitutes a stronger previous run. Display this round versus `app.previousBestScore`; first runs establish a record, ties do not claim a new record. Support replay on successful floors.
- [x] Use reduced-motion-safe stars, record celebrations, clear statistics, friendly competitive copy, and accessible controls. Reword About around practice performance and honest progress.
- [x] Coordinate with the primary agent for one combined Xcode build; inspect the resulting UI.

## 3. Interaction and feedback (game agent)

Files: Features/Game/*, Services/SoundEngine.swift, Services/HapticsEngine.swift, App/TestIQApp.swift, optionally Core/Support/PuzzleInteraction.swift plus focused tests. No writes to shared AppState, Home, Report, or persistence.

- [x] Add optional first-use interactive warmups for choice, sequence/grid memory, ordering, and word tiles. Store learned interaction keys through AppState. Pause the challenge timer for the warmup. Do not charge points or hints during it.
- [x] Add readable point feedback, combo milestones, encouraging contextual reactions, and the existing technique after an answer. Keep next action immediately available and avoid mandatory long animations.
- [x] Reproduce and test interaction defects exposed by the loop: completed echo sequences must submit; grid recall compares sets; repeated-letter undo restores the actual chosen tile. Keep existing behavior consistent for other families.
- [x] Honor haptic enablement on every cue and initialize it from saved preferences. Guard audio scheduling on a ready graph; discard stale cues when muted. Correct sound rises with combo, record/clear moments get distinct accents.
- [x] Keep memory presentation cancellation safe and all effects usable without sound or motion. Coordinate app build with primary agent.

## 4. Progress and coaching (report agent)

Files: Features/Report/*, optional Core/Scoring/CoachingEngine.swift copy changes. No writes to shared models, Home, Game, AppState, or store.

- [x] Replace headline IQ/percentile gauge with practice progress: recorded rounds, recent accuracy, earned stars, and clear labels distinguishing personal records from history.
- [x] Render `ProgressInsights.trends(in: app.progress.attemptHistory)` with accuracy/hints/pace and sample context; insufficient history explains how to build a comparison. Display recent actual rounds chronologically/per selected floor, including weaker results. No unlabelled mixture of adaptive difficulties.
- [x] Keep coaching specific and constructive. Turn the suggested replay floor into a working button, honoring unlock state. Remove unsupported intelligence claims from visible report copy.
- [x] Ensure long reports, empty states, reduced motion, and text scaling remain readable.

## 5. Integration and verification

- [x] Independently review spec coverage, then review code correctness and accessibility. Resolve findings before completion.
- [x] Run `swift test` and `xcodebuild -project TestIQ.xcodeproj -scheme TestIQ -sdk iphonesimulator -destination 'id=80A85139-3181-4151-AC49-8D82AF801853' -derivedDataPath /tmp/testiq-arcade-build build CODE_SIGNING_ALLOWED=NO`.
- [x] Boot/install/launch on the iPhone simulator. Inspect home, first-use warmup, play, weaker replay completion, and progress. Verify saved preferences and a legacy-save fixture. Use a dedicated simulator save for fixtures; preserve existing data.
- [x] Save verification notes, inspect `git diff --check`, and record distilled outcomes in UAMS. Leave the build reviewable on `codex/arcade-ascent`; no publication requested.

Verification results and manual-check limits: [Arcade Ascent verification](../../verification/arcade-ascent/verification.md).
