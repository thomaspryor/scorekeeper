# Scorekeeper - Project Context

## Overview
A mobile-first web app for tracking scores during board games. Inspired by the discontinued iOS app "Scorekeeper XL" by Matt Rix.

**Live URL:** https://thomaspryor.github.io/scorekeeper/
**GitHub:** https://github.com/thomaspryor/scorekeeper

## Tech Stack
- Vanilla HTML/CSS/JavaScript (no frameworks, no build step)
- ~1,200 lines JS, ~760 lines CSS
- localStorage for persistence
- Web Audio API for sounds
- PWA-ready (manifest.json, works offline)

## Features
- Add/remove players with 12 color choices
- +/- buttons with long-press for rapid scoring
- Running total display (e.g., "5 + 3 = 8")
- Swipe left to delete, swipe right to edit
- Drag handle to reorder players
- Sort/unsort by score (manual, not auto)
- Undo (50 actions, button or shake device)
- Sound effects + haptic feedback
- Toast notifications with undo option
- iOS edge protection (ignores swipes near screen edge)
- Responsive: portrait + landscape modes
- PWA install prompt

## File Structure
```
scorekeeper/
├── README.md
└── docs/               # GitHub Pages serves from here
    ├── index.html      # Single page app
    ├── styles.css      # All styles
    ├── app.js          # All logic (IIFE pattern)
    ├── manifest.json   # PWA manifest
    └── preview.png     # Social preview image
```

## Data Model
```javascript
state = {
  players: [
    { id: "abc123", name: "Tom", score: 15, color: "#FF4136" }
  ],
  soundEnabled: true,
  isSorted: false,
  originalOrder: ["abc123", ...] // for unsort
}
```

## Color Palette (12 colors, in order)
Red, Orange, Yellow, Green, Lime, Cyan, Blue, Purple, Pink, Gray, Black, White

## Layout
- **Top toolbar:** Add Player, Undo, Sort
- **Player rows:** Drag handle | Name | Score | - | +
- **Bottom toolbar:** Reset Scores, New Game, Sound toggle

## Known Limitations
- Haptics don't work on iOS (no Vibration API)
- PWA install banner doesn't show on iOS Safari (use Share → Add to Home Screen)
- Undo stack not persisted across page reloads
