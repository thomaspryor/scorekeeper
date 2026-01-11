# Scorekeeper App - Technical Context Document

## Overview

Scorekeeper is a mobile-first Progressive Web App (PWA) for tracking scores during board games, card games, and party games. It's built with vanilla HTML/CSS/JavaScript with zero dependencies.

**Live Demo:** https://thomaspryor.github.io/scorekeeper/

## Project Structure

```
/docs                    # Main app files (in /docs for GitHub Pages)
  ├── index.html         # Single HTML page (~110 lines)
  ├── app.js             # All JavaScript logic (~1,210 lines)
  ├── styles.css         # Complete stylesheet (~760 lines)
  ├── manifest.json      # PWA manifest
  └── preview.png        # Social media preview image
README.md                # Project documentation
```

## Architecture

### State Management

The app uses a simple in-memory state object persisted to localStorage:

```javascript
let state = {
  players: [],        // Array of {id, name, score, color}
  soundEnabled: true,
  isSorted: false,
  originalOrder: []   // Player IDs in unsorted order (for unsort feature)
};
```

**Key state flows:**
- All mutations call `saveState()` to persist to localStorage
- `loadState()` runs on init to restore previous session
- Undo stack maintains up to 50 snapshots for undo functionality

### Player Data Model

```javascript
{
  id: string,      // Unique ID via generateId() (timestamp + random)
  name: string,    // Display name (defaults to "Player N" if empty)
  score: number,   // Current score (integer)
  color: string    // Hex color from COLORS palette
}
```

### Color Palette

12 predefined colors matching the original Scorekeeper XL order:
```javascript
const COLORS = [
  '#FF4136', // Red
  '#FF851B', // Orange
  '#FFDC00', // Yellow
  '#2ECC40', // Green
  '#01FF70', // Lime
  '#39CCCC', // Cyan
  '#0074D9', // Blue
  '#B10DC9', // Purple
  '#F012BE', // Pink/Magenta
  '#AAAAAA', // Gray
  '#111111', // Black
  '#FFFFFF', // White
];
```

## Core Features

### 1. Score Manipulation
- **Tap +/-:** Single increment/decrement
- **Long press +/-:** Rapid fire (starts at 150ms intervals, accelerates to 50ms after 10 increments)
- **Running total display:** Shows "baseScore ± delta = newScore" for 2 seconds after changes
- **Score animation:** Bump animation on score change

### 2. Player Management
- **Add player:** Via toolbar button or inline "Add Player" button
- **Edit player:** Swipe right to open edit modal (name + color picker)
- **Delete player:** Swipe left (instant delete with undo toast)
- **Reorder:** Drag handle on left side of each row

### 3. Sorting
- **Sort:** Orders players high-to-low by score
- **Unsort:** Restores original (manual) order
- **Animation:** Staggered slide-in animation on sort
- **Sound:** Rising arpeggio (C5-E5-G5-C6) on sort

### 4. Undo System
- **Undo button:** In top toolbar
- **Shake to undo:** DeviceMotion API (iOS 13+ requires permission)
- **Toast undo:** Destructive actions show toast with "Undo" button for 4 seconds
- **Stack limit:** 50 undo states max

### 5. Reset Functions
- **Reset Scores:** Sets all scores to 0 (with undo toast)
- **New Game:** Clears all players (with undo toast)

### 6. Audio & Haptics
- **Score sound:** 880Hz sine wave, 80ms
- **Sort sound:** C major arpeggio
- **Haptic patterns:** light (10ms), medium (20ms), heavy (30ms), success, warning
- **Toggle:** Sound can be disabled via toolbar

### 7. PWA Features
- **Installable:** Web app manifest with icons
- **Install banner:** Prompts user to install (dismissable, remembered)
- **Standalone mode:** Full screen when installed

## UI Components

### Layout
```
┌─────────────────────────────┐
│      Top Toolbar            │  [+Player] [Undo] [Sort]
├─────────────────────────────┤
│                             │
│      Player List            │  Scrollable player rows
│      (main content)         │
│                             │
├─────────────────────────────┤
│      Bottom Toolbar         │  [Scores] [Game] [Sound]
└─────────────────────────────┘
```

### Player Row Structure
```
┌─────────────────────────────────────────────────┐
│ ⋮⋮ │ PLAYER NAME │ 0 + 5 = │ 5 │ [-] │ [+] │
│ drag│             │ delta   │score│     │     │
└─────────────────────────────────────────────────┘
```

Swipe backgrounds:
- Right swipe: Blue edit icon
- Left swipe: Red delete icon

### Edit Modal
```
┌─────────────────────────────┐
│   [color swatches 6x2]      │
│                             │
│ [🗑️] [___name input___] [✓] │
└─────────────────────────────┘
```

### Toast Notifications
- Positioned above bottom toolbar
- Shows message with optional "Undo" button
- Auto-dismisses after duration (default 3s, destructive actions 4s)

## Event Handling

### Touch Interactions
| Gesture | Target | Action |
|---------|--------|--------|
| Tap | +/- button | Single score change |
| Long press | +/- button | Rapid score change |
| Swipe left | Player row | Delete player |
| Swipe right | Player row | Open edit modal |
| Drag | Drag handle | Reorder players |
| Tap | Empty state | Add first player |
| Shake | Device | Undo |

### Edge Protection
- Swipes starting within 25px of screen edges are ignored (prevents iOS back/forward gesture conflicts)

### Double-tap Prevention
- Double-tap zoom is disabled via touch event handling

## Responsive Design

### Breakpoints
- **Portrait (default):** Standard sizing
- **Landscape:** Reduced padding, smaller elements
- **Small landscape (max-height: 400px):** Compact mode, hides some labels
- **Tablet (min-width: 768px):** Larger touch targets and fonts

### Safe Areas
- Uses `env(safe-area-inset-*)` for notched devices
- Toolbars respect safe areas
- Modal respects horizontal safe areas

## CSS Architecture

### Naming Conventions
- BEM-like: `.player-row`, `.player-name`, `.score-btn`
- State classes: `.selected`, `.dragging`, `.visible`, `.hiding`
- Modifier classes: `.sound-off`, `.bump`

### Key CSS Features
- CSS Grid for player row layout
- Flexbox for toolbars and modals
- CSS custom properties: none (colors inline)
- Animations: `@keyframes bump`, `@keyframes toastIn`, `@keyframes toastOut`

## Technical Notes

### Browser APIs Used
- `localStorage` - State persistence
- `AudioContext` / `webkitAudioContext` - Sound generation
- `navigator.vibrate` - Haptic feedback
- `DeviceMotionEvent` - Shake detection
- `beforeinstallprompt` - PWA install prompt

### iOS Considerations
- AudioContext requires user gesture to create/resume
- DeviceMotion requires explicit permission on iOS 13+
- Uses `-webkit-overflow-scrolling: touch` for smooth scrolling
- Safe area insets for notched devices

### Performance
- Minimal DOM manipulation via targeted `renderPlayerScore()`
- No framework overhead
- CSS transitions hardware-accelerated
- Touch events use `passive: true` where possible

## Key Functions Reference

### State Management
- `loadState()` - Load from localStorage
- `saveState()` - Persist to localStorage
- `pushUndo()` - Snapshot current state
- `undo()` - Restore previous state

### Player Operations
- `addPlayer()` - Create new player
- `removePlayer(id, skipToast)` - Delete player
- `updatePlayer(id, updates)` - Modify player
- `changeScore(id, delta, isLongPress)` - Adjust score

### UI
- `render()` - Full re-render of player list
- `renderPlayerScore(id, score, baseScore, delta)` - Update single score display
- `openEditModal(playerId, isNewPlayer)` - Show edit modal
- `showToast(message, options)` - Display notification

### Utilities
- `generateId()` - Create unique ID
- `getNextColor()` - Get next unused color
- `getTextColor(bgColor)` - Calculate contrast text color
- `escapeHtml(str)` - XSS prevention

## Development

### Running Locally
```bash
# Serve from docs directory
python -m http.server 8000 --directory docs
# Open http://localhost:8000
```

### Deployment
Files are in `/docs` for direct GitHub Pages hosting from the main branch.

### No Build Process
- Plain HTML/CSS/JS
- No transpilation
- No bundling
- No dependencies

## Future Considerations

Areas where the app could be extended (not currently implemented):
- Score increment customization (+5, +10, custom)
- Score history/log per player
- Multiple game sessions
- Import/export data
- Themes/dark mode toggle
- Sound selection
- Multiplayer/sync
