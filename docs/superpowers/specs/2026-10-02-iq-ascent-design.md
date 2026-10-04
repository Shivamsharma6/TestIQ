# IQ Ascent — Design Spec

> Status: approved (user delegated all design decisions and requested uninterrupted execution)

## 1. Product

**IQ Ascent** is an iOS puzzle game that measures reasoning ability across 10 themed
levels and produces a personalised, honest performance report at the end.

The player climbs a 10-floor vertical path. Each floor is a cognitive domain with its
own puzzle archetypes, difficulty ramp, time limit and hint budget. Clearing a floor
unlocks the next. Clearing floor 10 unlocks the **Assessment Report**.

Product name on screen: **IQ ASCENT** · tagline: *"Ten floors. One mind."*

Non-goals: not a clinical IQ instrument, no ads, no accounts, no network, no IAP.

## 2. Platform & Framework Decision

The repo is a stock Xcode SpriteKit template. SpriteKit is a real-time game engine; this
product is a menu-driven puzzle game with data-heavy report screens. **Decision: replace
SpriteKit with SwiftUI** and delete `GameScene.swift`, `GameViewController.swift`,
`GameScene.sks`, `Actions.sks`.

Consequences handled explicitly:

- `Main.storyboard` deleted, `UISceneStoryboardFile` removed from `Info.plist`, and
  `INFOPLIST_KEY_UIMainStoryboardFile` removed from `project.pbxproj` (a build-setting
  deletion — file *addition* is still handled by Xcode's folder synchronisation, so
  `project.pbxproj` needs no file entries).
- `SceneDelegate` builds the window and hosts a `UIHostingController`.
- Target settings stay untouched otherwise: iOS 27.0 min, Swift 5 language mode,
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, iPhone + iPad.

The target uses `PBXFileSystemSynchronizedRootGroup`, so every `.swift` file dropped
under `TestIQ/` is compiled automatically. No manual `project.pbxproj` file wiring.

## 3. Architecture

Three concentric rings. The inner ring has no UI dependency whatsoever.

```
TestIQ/Core/        pure Foundation. models, RNG, 19 puzzle generators,
                    IQRating, ScoringEngine, Assessment, CoachingEngine.
TestIQ/Design/      Theme + Motion tokens.
TestIQ/Components/  reusable SwiftUI building blocks.
TestIQ/Features/    Home / Game / Report views + view models.
TestIQ/Services/    ProgressStore, HapticsEngine, SoundEngine, AppState.
TestIQ/App/         @main App, RootView.
```

`Core` compiles unchanged for macOS and is exercised by a SwiftPM package declared at
the repo root with `path: "TestIQ/Core"`, so `swift test` verifies the scoring maths and
all 19 generators on the command line. The iOS app consumes the same files through
folder synchronisation. One source of truth, two build systems.

**Hard rule:** nothing in `Core/` may `import UIKit` or `import SwiftUI`. That is what
keeps the game logic testable and the report numbers defensible.

### File map

| Path | Responsibility |
| --- | --- |
| `Core/Random/SeededGenerator.swift` | SplitMix64. Deterministic, seedable, testable. |
| `Core/Model/CognitiveDomain.swift` | The 8 reported domains + display metadata. |
| `Core/Model/PuzzleKind.swift` | 19 puzzle kinds → domain mapping. |
| `Core/Model/Puzzle.swift` | `Puzzle`, `PuzzleOption`, `PuzzleStimulus`, `ShapeSpec`, `MatrixSpec`, `MemorySpec`. |
| `Core/Model/LevelDefinition.swift` | The 10-level catalogue. |
| `Core/Model/Attempt.swift` | `ItemResult`, `LevelResult`, `RunSummary`. |
| `Core/Scoring/IQRating.swift` | Normal CDF, θ→IQ, percentile, confidence interval, band. |
| `Core/Scoring/Assessment.swift` | Computed report model. |
| `Core/Scoring/ScoringEngine.swift` | Pure: `[ItemResult]` → `Assessment`. |
| `Core/Scoring/CoachingEngine.swift` | Weaknesses → specific technique + 5-minute drill. |
| `Core/Scoring/StarRules.swift` | End-of-run star thresholds. Lives here, not in the view. |
| `Core/Support/ShapeGeometry.swift` | Vertex outlines for all 12 shapes, plus the palettes rotation and mirroring require. |
| `Core/Generators/*.swift` | One file per puzzle family. |
| `Core/Generators/PuzzleFactory.swift` | Level → puzzle set, adaptive routing. |
| `App/TestIQApp.swift`, `App/RootView.swift` | Entry point, navigation. |

## 4. The 10 Levels

Difficulty rises monotonically. `θ` is the latent ability scale (≈ 2.8 = average).

| # | Floor | Domain focus | Items | Time | Item θ range | Star gate |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | First Steps | Pattern | 5 | 90 s | 1.0 – 2.0 | 60 % |
| 2 | Number Trail | Quantity | 6 | 100 s | 1.2 – 2.6 | 60 % |
| 3 | Word Vault | Verbal | 6 | 110 s | 1.2 – 2.8 | 62 % |
| 4 | Logic Lab | Deduction | 7 | 130 s | 1.4 – 3.2 | 65 % |
| 5 | Memory Vault | Working memory | 7 | 120 s | 1.4 – 3.2 | 65 % |
| 6 | Mind's Eye | Spatial | 7 | 130 s | 1.5 – 3.4 | 68 % |
| 7 | Pattern Matrix | Abstract | 8 | 150 s | 1.6 – 3.8 | 70 % |
| 8 | Numbers Lab | Quantity (hard) | 8 | 160 s | 1.8 – 4.2 | 72 % |
| 9 | Mixed Cortex | Adaptive, all 7 | 9 | 170 s | 2.0 – 4.6 | 75 % |
| 10 | The Zenith | All 7, hardest tier | 12 | 210 s | 2.6 – 5.2 | 78 % |

Stars: 3 = cleared **and** ≥ 88 % correct **and** ≥ 45 % clock remaining;
2 = ≥ 75 % correct; 1 = cleared.

## 5. Puzzle System

### 5.1 Archetypes

19 kinds collapse onto 4 interaction archetypes so the UI layer stays small:

| Archetype | Kinds |
| --- | --- |
| `choice` | sequence, oddOneOut, matrix, letterRelation, truthLiar, rotation, mirrorImage, foldedHoles, spatialCount, ratio, percentage, rate, probability, arithmetic |
| `echo` | memorySequence, gridRecall |
| `order` | ordering |
| `scramble` | anagram |

### 5.2 Domains

| Domain | Kinds |
| --- | --- |
| Pattern Recognition | sequence (tiers 1–2), oddOneOut |
| Verbal Reasoning | anagram, letterRelation |
| Logical Deduction | truthLiar, ordering |
| Working Memory | memorySequence, gridRecall |
| Spatial Reasoning | rotation, mirrorImage, foldedHoles, spatialCount |
| Abstract Generalisation | matrix, sequence (tiers 3+) |
| Numerical Reasoning | ratio, percentage, rate, probability, arithmetic |
| Attention & Speed | *derived* from response latency across all items |

`Attention & Speed` has no puzzle kind. It is computed from median correct-response
latency as a fraction of the item's time limit, so it is a genuine cross-cutting
measurement rather than a duplicate of any one floor.

### 5.3 Stimulus vocabulary

Visual puzzles are described declaratively as `ShapeSpec { shape, fill, rotation,
handed, count }` over 12 shapes and 6 fills. `handed: -1` mirrors horizontally about the
shape's own centre, so rotation and mirror puzzles are *generated* rather than shipped as
bitmaps — the whole puzzle bank is a few kilobytes of code and scales with difficulty.
No image assets, no bundle, nothing to load.

The outlines themselves are generated as polygons in `Core/Support/ShapeGeometry.swift`,
not built as SwiftUI `Path`s in the view. That placement is deliberate and was added after
a shipped bug: an earlier version drew shapes with SwiftUI paths directly, and a
self-intersecting outline (the crescent, built from two arcs) rendered as *nothing* — an
option tile that looked empty and silently cost the player the item. Generating geometry
in `Core` makes that class of failure assertable, and `ShapeGeometryTests` now checks that
every shape has usable area and fills both dimensions of its box at any scale.

`ShapeGeometry` also owns two palettes that encode a correctness requirement rather than
a preference:

- `rotationSensitive` — shapes whose silhouette actually changes under a 90° turn.
- `handed` — shapes that have a left and a right, so mirroring them is observable.

A cross or a square is identical to itself after either operation. An earlier build drew
rotation and matrix items from the full shape list, which produced grids whose "rule" was
invisible and rotation items with no distinguishable answer. Every generator whose
difficulty depends on rotation or mirroring now draws from these palettes, and a test
asserts it.

## 6. Scoring Model

The headline number is presented as an **estimate with an interval**, never as a precise
measurement. That is both more honest and more interesting to look at.

### 6.1 Per-item score

```
timeBonus    = 0.35 × (1 − min(elapsed / timeLimit, 1.5))      // +0.35 … −0.175
hintPenalty  = 0.45 × hintsUsed
itemScore    = correct ? clamp(item.θ + timeBonus − hintPenalty, 0, 6) : 0
```

Timeouts and skips score 0 and are recorded as errors so that abandoning hard items
lowers the score, as it should.

### 6.2 Per-domain θ

`θ_domain = mean(itemScore for that domain)`. Domains with fewer than 2 items are
shrunk toward the global mean:

```
θ_shrunk = (n · θ_domain + 5 · θ_global) / (n + 5)
```

so a lucky single item cannot manufacture a "superior" domain.

### 6.3 Composite → IQ → percentile

```
composite   = mean(θ_shrunk)                       // equal weight per domain
z           = (composite − 2.80) / 0.85
iqEstimate  = 100 + 15 × z
percentile  = 100 × Φ(z)
```

Band (standard deviation bands), asserted only when the confidence interval stays inside
one band: `≤ 70 Very Low`, `< 85 Low`, `< 115 Average`, `< 130 High`, else `Very High`.

### 6.4 Confidence interval

`se(θ) = 0.85 / sqrt(max(N, 8) / 12)`, widened by consistency of performance:

```
dispersion = stdev(itemScore) across all items
se        += 0.35 × dispersion
ciLow     = 100 + 15 × (z − 1.96 × se)
ciHigh    = 100 + 15 × (z + 1.96 × se)
```

A 12-item, inconsistent run produces a wide interval and the UI says so. Honest
uncertainty is a feature.

## 7. Coaching Engine

Generic "do more puzzles" advice is worthless, so nothing in the report is generic.

Two generators feed the coaching section:

1. **Domain weaknesses.** Any domain whose θ is more than 0.40 below the composite gets a
   card containing: the observed numbers, a named technique for that item type
   ("difference ladder", "two-line scan", "fold-line mirroring"), and a concrete 5-minute
   drill described in enough detail to actually perform.
2. **Error clustering.** Errors are grouped by `skillTag` (e.g. `alternating-difference`,
   `mirror-handedness`, `fold-symmetry`). If a tag accounts for ≥ 2 errors, the card names
   the tag, counts the errors, and gives the specific technique for that tag.

Each weakness card also proposes which floor to replay.

## 8. Interaction Design

- **Home.** Vertical scrolling path of 10 nodes on a spline. Locked nodes are dimmed with
  a lock glyph; cleared nodes carry 0–3 stars; the next available node pulses.
- **Level intro.** Floor name, domain badge, item count, time, best stars. "Ascend".
- **Game.** Full-bleed puzzle card. HUD shows remaining items as pips, a depleting timer
  ring, the combo multiplier, and hint charges.
  - Correct → particle burst at the tap point, medium haptic, rising arpeggio tone,
    combo increments to ×5, card springs forward.
  - Wrong → card shakes, rigid haptic, descending buzz, combo resets. A wrong answer is
    not instantly fatal; the item is scored and the run continues, because a punishing
    loop measures anxiety, not ability.
  - Hint → deducts a star charge and reveals a scaffolded clue, never the answer.
  - Timer under 20 % → HUD ring turns amber then red and pulses.
- **Level complete.** Star burst, score count-up, run statistics, continue / replay.
- **Report.** Reveals in ordered sections with an animated gauge, an 8-axis radar chart
  drawn in `Canvas`, per-domain bars, strengths, weaknesses with drills, per-floor
  accuracy breakdown, and a plain-language disclaimer.
- **Audio.** `AVAudioEngine` synthesises every sound from PCM buffers at runtime —
  zero audio assets, tiny binary, no licensing questions.
- **Haptics.** `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator`, one call
  site per event.
- **Accessibility.** Dynamic Type throughout, VoiceOver labels and hints on every
  control, 44 pt minimum targets, `.accessibilityReduceMotion` honoured (particles,
  confetti, pulses and count-ups collapse to instant states), and a colour-blind-safe
  palette where correctness is conveyed by icon + colour + motion together.

## 9. Persistence

`ProgressStore` writes one Codable `PlayerProgress` to Application Support as JSON:
highest unlocked level, per-level best stars and best accuracy, lifetime totals, and the
stored final `Assessment`. Reads are cached in memory; writes are atomic. A corrupt or
missing file yields a fresh profile rather than a crash.

## 10. Verification

1. `swift test` — 88 unit tests across `IQRating`, `ScoringEngine`, `CoachingEngine`,
   `StarRules`, `ShapeGeometry`, `LevelCatalog` and all 19 generators: determinism,
   answer validity, option uniqueness, difficulty monotonicity, solvable truth-or-lie,
   non-degenerate geometry, rotation sensitivity, and that no advice is generic.
2. `xcodebuild -sdk iphonesimulator -destination 'id=<iPhone 18 Pro, iOS 27.0>' build`
   must print `** BUILD SUCCEEDED **`.
3. Boot the simulator, install, launch, and capture screenshots of home, game and report
   to confirm it actually renders and runs.