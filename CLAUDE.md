# Scorekeep: Project Rules

Score tracker for game night: a web app (scorekeep.co) and a native iOS app (App Store).
Keep this file under 100 lines. Details go in `memory/{topic}.md` with a pointer here.

## CRITICAL RULES

### 1. Never ask the owner to run local commands
The owner is not technical and often on a phone. Automate everything through
GitHub Actions: tests, builds, screenshots and App Store releases all run in CI.
If something truly needs the owner (App Store Connect clicks, a GitHub secret),
give exact steps with links, once, and say why it can't be automated.

### 2. Git workflow
- `git branch --show-current` before ANY commit or push.
- Work on a branch, open a PR, get CI green, then merge it yourself: the owner
  does not review PRs. Pushing to `master` deploys the website.
- Commit after each logical unit; never leave work uncommitted or unpushed.

### 3. Test before committing (mandatory)
- iOS: `ios.yml` runs unit + UI tests on a simulator, checks the Xcode project
  matches `ios/project.yml`, and captures screenshots. It must be green.
- Pure game rules (`ios/Scorekeep/Logic`, `Models`) also run on Linux Swift;
  recipe in `memory/testing.md`. Use it to catch errors before a CI round trip.
- Web: `web.yml` runs `scripts/web-smoke.mjs` (Playwright, phone size). Extend
  it for new flows; screenshot UI changes before shipping.
- New tests go next to the existing ones; workflows pick up whole test targets,
  never list test files one by one.

### 4. Fix systematically
Every fix includes prevention (a test, a CI check, a guard) and a look for the
same bug elsewhere, including the other platform (web ↔ iOS).

### 5. Never guess or fake data
Store listing claims must match what the app actually does. Privacy answers
must match the code: `memory/app-store.md` lists what the app stores and why.

### 6. Always recommend next steps
When wrapping up, name the best next task. Don't just say "done".

## Architecture
- **Web** (`docs/`): vanilla HTML/CSS/JS, no framework, no build step, no
  dependencies. `index.html`, `app.js` (all logic and UI), `styles.css`,
  `manifest.json`. Data in localStorage. No service worker yet.
  `privacy.html` and `support.html` are the App Store privacy/support URLs.
- **iOS** (`ios/`): SwiftUI, iOS 17+, Swift 6, no dependencies. Data in
  UserDefaults. `ios/project.yml` (XcodeGen 2.46.0) is the source of truth for
  `Scorekeep.xcodeproj`: edit the yml, regenerate, commit both.
  - `Logic/`: pure rules (sorting, winners, trash talk). Keep UI out of it.
  - `ViewModels/GameViewModel.swift`: state, undo, persistence, history.
  - `Utilities/DemoData.swift`: `-demo <scenario>` launch argument for
    screenshots and UI tests. Never touches the user's saved game.
- **Feature parity:** both apps should offer the same features. Gaps and the
  plan: `memory/feature-parity.md`.

## Deployment
- **Web:** Vercel, root `docs`, domain scorekeep.co, auto-deploys on push to `master`.
- **iOS:** `ios-release.yml` (manual dispatch) builds, uploads to TestFlight,
  pushes the listing (`ios/fastlane/metadata`) and fresh screenshots, and with
  `submit_for_review=true` sends the build to App Review. Bundle ID
  `co.scorekeep.app`, team `2837Q6TK6Y`. Setup, secrets, review answers and
  release history: `memory/app-store.md`.
- **One release per session, at the end.** Batch fixes, ship once.
- TestFlight builds need no owner sign-off. **App Store submission needs the
  owner's go-ahead** (bump `MARKETING_VERSION` in `ios/project.yml` first).

## Design
- Dark UI, black background. Player rows are full-bleed bars in the player's
  color with auto black/white text. Palette (both apps): `#FF4136 #FF851B
  #FFDC00 #2ECC40 #01FF70 #39CCCC #0074D9 #B10DC9 #F012BE #AAAAAA #111111 #FFFFFF`.
- Mobile first, one-handed, readable across a table. Fast, tactile feedback:
  haptics, synthesized sounds, swipe gestures.
- Every control needs a VoiceOver label (iOS) or `aria-label` (web).
- iPad matters: App Review often tests on iPad. Check the iPad screenshot.

## Security
Public repo. Never commit secrets. gitleaks runs pre-commit
(`./scripts/setup-git-hooks.sh` once per clone) and in CI.
