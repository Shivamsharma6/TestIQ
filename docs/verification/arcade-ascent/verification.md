# Arcade Ascent verification

Verified on 2026-10-04 on branch `codex/arcade-ascent`.

## Automated checks

- `swift test`: **118 tests passed, 0 failures** (baseline: 88). Includes save migration, exact-once history, latest versus best, preserved stars/unlocks, legacy high-score retention, comparison eligibility and accuracy/hint tradeoffs, memory input, repeated-letter undo, corrupt-save recovery, save failures, floor accuracy gates, and shape-specific coaching.
- Debug and Release simulator builds: **BUILD SUCCEEDED** using `xcodebuild -project TestIQ.xcodeproj -scheme TestIQ -configuration Debug` (and `Release`) `-sdk iphonesimulator -destination 'id=AB2CD9A4-BDF5-4341-B2AF-55C088E66D1E' -derivedDataPath /tmp/testiq-arcade-build build CODE_SIGNING_ALLOWED=NO`.
- No Swift source warnings in these builds. Xcode emits the standard metadata extraction warning because the app has no AppIntents dependency.
- `git diff --check`: passed.

Tests reproduced legacy record loss, a star gate bypass, and the shape-coaching mismatch before their fixes. An independent static review checked progression, pause behavior, sound, and final accessibility labels. Findings were addressed.

## Simulator checks

Used a dedicated iPhone 17e simulator, “TestIQ Arcade QA,” on iOS 27.0. Existing progress on the separate iPhone 18 Pro simulator was preserved.

- Fresh home → first-floor introduction → interactive choice warmup → timed puzzle. Warmup has no active timer or points.
- Played all five items: four correct, one incorrect, 614 points, 80% accuracy, two stars. Point/combo feedback and technique are visible; Next puzzle remains available. Floor 2 unlocks.
- Replayed the cleared floor with all five incorrect: completion shows the new 0-point round and earlier 614-point best. Stars and the unlock remain earned.
- Progress shows two chronological rounds (80%, then 0%), the latest result, the separate record, and an honest insufficient-history comparison state.
- Coaching replay opens the suggested floor. The corrected shape card teaches outline, fill, rotation, count, and arrangement.
- Sound and haptics toggled off; both settings and the two completed rounds remain after termination, reinstall, and relaunch.
- First-use memory warmup accepts the repeated sequence 1 → 3 → 1. Live memory presentation ends, unlocks the tiles, and then starts the answering window.
- Home inspected at standard and accessibility-large text sizes on the smaller phone. Decorative emblem yields space at accessibility sizes; headline punctuation stays with its words.
- Accessibility tree inspected for navigation, timer, feedback, history, and memory controls. Shape choices now carry explicit labels matching the displayed shape count.
- Existing legacy profile visually retains its records and rewards while showing zero recorded historical rounds, rather than inventing past attempts.

## Remaining hardware checks

Reduced-motion branches were reviewed in code: stars remain visible, effects are finite or disabled, and record text remains available. A full VoiceOver session and a device-level Reduce Motion walkthrough were not performed. Audio scheduling/muting was checked in code and preferences on the simulator; sound quality and physical haptic feel still need a real iPhone pass.

These practice statistics measure game performance. They do not establish or guarantee an IQ change. Head-to-head live battles remain deferred as requested.

## Screenshots

- [Home](home.png)
- [Progress after the weaker replay](progress.png)
