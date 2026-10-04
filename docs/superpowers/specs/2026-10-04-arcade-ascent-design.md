# Arcade Ascent

Approved on 2026-10-04: build the recommended energetic, competitive single-player arcade direction. Head-to-head live battles are deferred. The approval covers implementation in this session.

## Experience

The loop is play, build a combo, learn a technique, challenge a personal best, and see progress. Keep the ten-floor ascent, existing puzzle families, and native SwiftUI architecture. Home leads with an immediate play action and a personal challenge; the map remains available below it. Use vivid lime/violet accents on dark surfaces, generous tap targets, concise instructions, and restrained arcade typography.

Teach unfamiliar interactions using a short optional interactive warmup before its timer starts. Correct answers show earned points and a growing combo; mistakes offer an encouraging reaction and the existing puzzle technique. Celebrations distinguish a floor clear from a personal record. Audio cues are short and synchronized with visible feedback. Sound, haptic, and reduced-motion settings must work throughout.

## Honest progress

Persist each completed attempt once, including weaker replays. Preserve previous saves, unlocked floors, and earned stars. Legacy best attempts remain records, not fabricated historical baselines. Display the just-completed round separately from the personal best. Arcade points are game achievements; do not describe them as IQ or population percentiles.

Progress includes a chronological recent-round view and comparable practice trends. Compare earlier and recent groups only when there are at least four recorded rounds on a floor and sufficient matching puzzle-kind/difficulty/time-limit samples. Display accuracy, hints, and correct-response pace with sample context. Do not call faster play improvement if accuracy declines. Insufficient history gets an actionable empty state. No invented statistics or guaranteed IQ claims.

## Architecture and scope

Move the Codable PlayerProgress value into Core so migration, duplicate protection, earned rewards, and history can be tested using SwiftPM. ProgressStore remains the JSON I/O boundary; AppState carries the latest completion and pre-round personal record. Pure progress helpers calculate comparisons. Views consume those values and route coaching replay to unlocked floors. Preserve the current generated puzzles and offline operation; no networking, accounts, live battles, daily punishment, or paid features.

Keep the legacy assessment models readable for save compatibility, but replace user-facing IQ/percentile presentation with actual practice measures. Current-session coaching uses recent recorded attempts with existing bests as a fallback for legacy saves.

## Verification

Start with the existing 88 core tests. Add behavior-first tests for old-save decoding, exact-once recording, weaker replay history, preserved unlocks/stars, round counters, comparison eligibility, and speed/accuracy tradeoffs. Test interaction corrections where the new onboarding and feedback exercise them. Build the simulator target; visually inspect home, warmup, play, latest results, and progress. Check reduced motion, sound/haptic preferences, small-screen layout, and VoiceOver labels. Record actual checks and any hardware-only limitations.
