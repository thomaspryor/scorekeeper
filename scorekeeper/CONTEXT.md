# Scorekeeper App - Development Context

## Quick Summary
Mobile-first web app for tracking scores in board games. Vanilla JS, no frameworks. Inspired by discontinued iOS app "Scorekeeper XL".

## File Structure
```
scorekeeper/
├── index.html      # Single page app shell
├── styles.css      # All styles (~700 lines)
├── app.js          # All logic (~1000 lines)
├── manifest.json   # PWA manifest
└── CONTEXT.md      # This file
docs/               # Copy for GitHub Pages deployment
```

## Core Features
- Add/edit/remove players with 12 color choices
- +/- score buttons with long-press acceleration
- Running total display ("0 + 10 = 10")
- Sort/Unsort toggle (manual, not auto-sort)
- Undo (50 actions, in-memory only)
- Sound effects (Web Audio API, Safari-compatible)
- Haptic feedback (Android only)
- Swipe left to delete players
- Drag handle to reorder players
- Score history per player (tap badge to view)
- Reset scores (keeps players, clears scores + history)
- New Game (removes all players)
- Big onboarding button for empty state
- PWA install prompt
- localStorage persistence

## State Structure
```javascript
state = {
  players: [{ id, name, score, color, history: [{delta, score, time}] }],
  soundEnabled: true,
  isSorted: false,
  originalOrder: [] // for unsort
}
```

## Layout
- **Top toolbar:** Add Player, Undo, Sort/Unsort
- **Player rows:** Drag handle | Name | History badge + Score | - | +
- **Bottom toolbar:** Reset, New Game, Sound toggle

## Key Technical Decisions
- IIFE pattern for encapsulation
- No build step, no dependencies
- Touch events with passive: false where preventDefault needed
- Event delegation on playerList for dynamic content
- CSS Grid for player rows (5 columns: drag, name, score-display, minus, plus)
- 3D borders on rows (light top, dark bottom)

## Known Limitations
- Haptics don't work on iOS (no Vibration API)
- PWA install banner doesn't appear on iOS Safari (must use Share > Add to Home Screen)
- Undo stack not persisted across page reloads

## Recent Changes (Latest First)
1. Fixed modal going off screen, added New Game button, 3D row borders
2. Added 5 features: haptic, swipe-delete, drag-reorder, history, PWA
3. Added sort animation + ta-dah sound + onboarding empty state
4. Fixed bugs: passive listener conflict, empty state click stacking
5. Added running total display, undo, confirmations
6. Changed layout from sidebars to top/bottom toolbars

## Colors (in order)
Red, Orange, Yellow, Green, Lime, Cyan, Blue, Purple, Pink, Gray, Black, White

## Branch
`claude/plan-scorekeeper-app-GQObF`
