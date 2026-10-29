# Testing: Scorekeep

## Layers
1. **Game rules, pure Swift**: `ios/ScorekeepTests/GameLogicTests.swift` against
   `ios/Scorekeep/Logic` and `Models`. No UIKit/SwiftUI, so they also compile on
   Linux. Sorting, winners (including lowest-score-wins), trash talk placeholders,
   tolerant decoding.
2. **View model**: `ios/ScorekeepTests/GameViewModelTests.swift`. Undo (bursts of
   taps are one step, add+name is one step, stack cap), sort cycle, end game and
   rematch, persistence (relaunch, legacy `isSorted` migration, missing keys,
   corrupt data), history cap. Each test gets its own UserDefaults suite.
3. **UI smoke test**: `ios/ScorekeepUITests`. Launches with `-demo empty`, adds two
   players, scores, undoes, ends the game. Queries by VoiceOver label, so a missing
   label breaks it on purpose.
4. **Screenshots**: `ios/scripts/screenshots.sh` launches `-demo scoreboard|celebration|history`
   on the newest iPhone Pro Max and iPad Pro 13" simulators and checks pixel sizes.
   Look at the artifact after any UI change, iPad included.

5. **Web smoke test**: `scripts/web-smoke.mjs` drives `docs/` in headless Chromium
   at 390x844: naming, scoring, undo, end game, reload, no horizontal scroll on
   any page, no console errors. Locally: `NODE_PATH=$(npm root -g) node scripts/web-smoke.mjs`.
   It caught the name-field race (typing in the first 100ms was erased).

## What runs when
| Trigger | What | Where |
|---|---|---|
| PR / push to master touching `ios/` | project sync check, layers 1-3, screenshots | `ios.yml` |
| Release dispatch | layers 1-3 again, then build and ship | `ios-release.yml` |
| PR / push to master touching `docs/` | web smoke test | `web.yml` |
| Every commit | gitleaks | `scripts/hooks/pre-commit`, `gitleaks.yml` |

macOS minutes are free: the repo is public.

## Run the pure tests on Linux (cloud sessions)
No Xcode in the cloud container, so check rules code before spending a CI round trip:
```
# Swift 6.2.1 for Ubuntu 24.04 from download.swift.org, then:
mkdir -p pkg/Sources/Scorekeep pkg/Tests/ScorekeepTests
ln -s $PWD/ios/Scorekeep/{Models,Logic}/*.swift pkg/Sources/Scorekeep/
ln -s $PWD/ios/ScorekeepTests/GameLogicTests.swift pkg/Tests/ScorekeepTests/
# Package.swift: target "Scorekeep" + testTarget "ScorekeepTests" depending on it
cd pkg && swift test
```
Keep `Logic/` and `Models/` free of UIKit/SwiftUI imports so this keeps working.

## Regenerating the Xcode project
XcodeGen 2.46.0 builds on Linux with `swift build -c release` and reproduces the
committed project byte for byte. It needs `USER` set (`USER=ci xcodegen generate
--spec ios/project.yml`). CI fails if the committed project drifts.

## Rules learned the hard way
- **Swift 6 runtime isolation:** a selector-based NotificationCenter observer on a
  `@MainActor` class crashes when the notification posts off the main thread
  (AVAudioSession route changes do). Use block observers on `.main` +
  `MainActor.assumeIsolated`.
- **Silent switch:** `.ambient` (iOS) and Safari's default Web Audio both go
  quiet when the ring/silent switch is on silent, whatever the volume. The first
  TestFlight tester heard nothing on either app. Both now use playback (iOS
  `.playback` + `.mixWithOthers`, web `navigator.audioSession.type`); the in-app
  Sound button is the control. Guarded by a unit test and the web smoke test.
- **Gesture cancellation:** `DragGesture.onEnded` does not run when the system
  cancels a touch (a scroll takes over). Anything that must stop on release
  (timers) also needs `@GestureState` + `onDisappear`.
  Even that misses a touch cancelled within one frame (neither fires), so the
  hold-repeat loop also checks `isPressing` each step. The UI test holds + and
  checks the score stops after release.
- **Codable all-or-nothing:** a synthesized decoder fails the whole save when one
  key is missing, which wipes the user's game on update. Persisted types decode
  every field with a default; add a test for each migration.
- **A static named like an enum case** (`DemoScenario.history`) is a redeclaration
  error; the Linux check can't catch it if the file imports SwiftUI-only code.
- **Undo toasts go stale:** a toast's Undo pops whatever is on top of the stack. Any
  new undo step (or a separate undo) must close a pending Undo toast, on both
  platforms. Covered by `GameViewModelTests` and the web smoke test.
- **Shake runs behind sheets:** shake-to-undo must ignore shakes while a sheet,
  dialog or the celebration is open.
- **`Dictionary(uniqueKeysWithValues:)` traps on duplicate keys.** Use
  `uniquingKeysWith:` for anything built from saved data, and dedupe ids on load.
