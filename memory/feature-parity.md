# Feature parity: web (docs/app.js) vs iOS

| Feature | Web | iOS |
|---|---|---|
| Add / edit / delete players, 12-color palette | yes | yes |
| Tap +/-, hold for rapid change, step 1-100 | yes | yes |
| Running "+N" delta next to score | yes | yes (1.0) |
| Undo button + shake to undo, bursts are one step | yes | yes (1.0) |
| Sort cycle: high-low, low-high, original | yes | yes (1.0) |
| End game: winner, standings, confetti, fanfare, rematch | yes | yes (1.0) |
| Lowest score wins when sorted low-high | yes | yes (1.0) |
| Trash talk bar | yes | yes (1.0) |
| Save / load / delete past games | yes | yes |
| Drag to reorder | yes | yes |
| Gesture hints on first use | yes | yes (1.0.1) |
| Install banner (PWA) | yes | n/a |
| Offline (service worker) | no | n/a (native) |

Gesture tips: same five tips and trigger (second player added, once) in
`docs/app.js` (showGestureHints) and `ContentView.swift` (GestureHintsView).
Change both together.

Trash talk lines live in both `docs/app.js` (TRASH_TALK) and
`ios/Scorekeep/Logic/TrashTalk.swift`. Change both together.

## Gaps worth doing
- P2: web service worker for true offline use (CLAUDE.md used to claim it existed).
