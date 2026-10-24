# Scorekeep

Track scores for board games, card games, and party games. A mobile-first web app
plus a native iPhone and iPad app.

**[Try it live at scorekeep.co](https://scorekeep.co/)**

## Features

- Add/remove players with customizable colors
- Tap +/- to adjust scores, hold for rapid increment
- Swipe left to delete, swipe right to edit
- Drag to reorder players
- Sort by score, highest or lowest first
- End the game to crown a winner (lowest score wins when sorted low to high)
- Trash talk that reacts to the standings
- Save and reload past games
- Undo support (button or shake your device)
- Sound effects and haptic feedback
- Installable as a PWA (web) or from the App Store (iOS)
- No account required, data stays on your device

## Tech

- **Web** (`docs/`): vanilla HTML/CSS/JavaScript, no dependencies, hosted on Vercel.
- **iOS** (`ios/`): SwiftUI, iOS 17+, no dependencies. `ios/project.yml` generates
  the Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen).
  Tests, screenshots and App Store releases run in GitHub Actions
  (`ios.yml`, `ios-release.yml`).

## Development

```bash
# Just open index.html in a browser, or serve locally:
python -m http.server 8000 --directory docs
```

After cloning, run `./scripts/setup-git-hooks.sh` once to enable the
pre-commit secret scan (this repo has no `npm install` step to wire it in
automatically — see `scripts/setup-git-hooks.sh` for details).

Web files are in `/docs`; pushing to `master` deploys scorekeep.co.

## License

MIT
