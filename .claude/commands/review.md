Post-implementation QA for Scorekeep. Run after writing code and before merging or
shipping. Adapted from BroadwayScorecard-app's /review for a local-only, two-platform app.

## 1. Scope
`git diff origin/master --stat`. Note which platform changed (`docs/` web, `ios/` app,
or both) and which screens: scoreboard, edit sheet, increment picker, new game,
past games, celebration.

## 2. Automated checks (all must pass)
- iOS: `ios.yml` green on the PR head (tests, project sync, screenshots).
  Before pushing, run the Linux pure-logic tests if `Logic/` or `Models/` changed
  (`memory/testing.md`).
- If `ios/project.yml` changed: regenerate the project and commit both.
- Web: load `docs/index.html` in Playwright at 390x844, exercise the change, no
  console errors, no horizontal scroll.
- gitleaks: no findings.

## 3. Behavior audit (read the diff for each)
- **Undo:** does the new action push exactly one undo step? Does undo restore every
  field it changed (players, originalOrder, sortMode, increment)?
- **Persistence:** new persisted field decodes with a default so old saves still
  load? Test added for the migration?
- **Both platforms:** same feature and same wording on web and iOS?
  Update `memory/feature-parity.md`.
- **Edge cases:** 0 players, 1 player, 12+ players (palette wraps), negative scores,
  ties, long names (20 chars), increment 100.

## 4. Visual and accessibility
- Download the `app-store-screenshots` artifact: iPhone and iPad, nothing clipped,
  dark mode, text readable on every palette color (yellow, white, black rows).
- Every new control has a VoiceOver label / `aria-label`; the UI test queries by label.
- Narrow phones: toolbar labels fit (they stack under the icon when tight).

## 5. Store impact
If the change alters what the app does or stores, update the listing
(`ios/fastlane/metadata`) and the privacy answers (`memory/app-store.md`,
`docs/privacy.html`, `PrivacyInfo.xcprivacy`).

## Output
List findings as P0 (blocks shipping), P1 (fix now), P2 (note). Fix P0/P1 before
shipping, then re-run section 2.
