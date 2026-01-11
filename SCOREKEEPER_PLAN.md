# Scorekeeper Mobile Web App - Implementation Plan

## Overview

A mobile-first web app to replace **Scorekeeper XL** (by Matt Rix), which is no longer available on the App Store. The app provides a simple, elegant interface for tracking scores during board games, card games (Magic: The Gathering), party games, and RPGs (D&D hit points).

---

## Core Features (Based on Scorekeeper XL)

### 1. Player Management
- **Add players** - Tap button (top-left) to add new player
- **Remove players** - Skull & crossbones icon in edit mode
- **Edit player names** - Tap on player row to enter edit mode
- **Color-code players** - 12-color picker (Atari-style vibrant palette)

### 2. Score Tracking
- **Plus/Minus buttons** - Large `-` and `+` buttons on each row
- **Long press acceleration** - Hold button to count up/down quickly
- **Large, readable scores** - Bold score number prominently displayed
- **Support for negative scores** - For games that allow it

### 3. Scoreboard Controls
- **Sort players** - "123" button (top-right) sorts lowest-to-highest
- **Reset all scores** - Reload icon (bottom-left) resets to 0
- **Sound effects** - Speaker icon (bottom-right) toggles sounds
- **Auto-sort option** - Leading player can appear on top

### 4. Data Persistence (No Login Required)
- **Auto-save** - Every change instantly saved to localStorage
- **Survives everything** - Browser close, phone lock, app switch, device restart
- **Session recovery** - Resume exactly where you left off (common during board games)
- **No account needed** - Works offline, no signup, no cloud sync

---

## UI/UX Design (From App Screenshots)

### Layout (Mobile Portrait)

```
┌──────┬─────────────────────────────────────────┬──────┐
│      │                                         │      │
│  +   │  ███ MATT          15    [ - ] [ + ]   │ 123  │
│ user │                                         │ sort │
│      ├─────────────────────────────────────────┤      │
│      │  ███ KELSI         12    [ - ] [ + ]   │      │
│      ├─────────────────────────────────────────┤      │
│      │  ███ TOREN          7    [ - ] [ + ]   │      │
│      ├─────────────────────────────────────────┤      │
│  ↻   │  ███ NEVIS          4    [ - ] [ + ]   │  🔊  │
│reset │                                         │sound │
└──────┴─────────────────────────────────────────┴──────┘
   ↑                    ↑                           ↑
Dark gray          Colored rows              Dark gray
sidebar            (full width)              sidebar
```

### Player Row Design
Each player row spans the full width with:
- **Background**: Solid vibrant color (the entire row)
- **Name**: Bold, uppercase, left-aligned (e.g., "MATT")
- **Score**: Large bold number, center-right
- **Buttons**: `-` and `+` buttons on the right side

### Edit Mode (Tap on player)
```
┌─────────────────────────────────────────────────┐
│  Color Picker (12 colors, 2 rows of 6)          │
│  [🔴][🟠][🟡][🟢][💚][🩵]                        │
│  [🔵][🟣][🩷][⬜][⬛][⚫]                        │
├─────────────────────────────────────────────────┤
│  [ ☠️ ]  [ JOHN_________ ]  [ ✓ ]               │
│  delete     name input       confirm            │
└─────────────────────────────────────────────────┘
```

### Design Principles
- **Minimalist** - "No frills, no fuss" - only essential elements
- **Touch-friendly** - Large tap targets (buttons are big squares)
- **High contrast** - Black text on bright colors, readable anywhere
- **Bold typography** - Names in uppercase, scores prominent
- **Retro/Atari aesthetic** - Vibrant saturated colors, blocky design

### Color Palette (12 Atari-Style Colors)
```
Row 1:
- Red:      #FF4444
- Orange:   #FF9933
- Yellow:   #FFDD00
- Green:    #44DD44
- Lime:     #99FF33
- Cyan:     #00DDDD

Row 2:
- Blue:     #4488FF
- Purple:   #AA44FF
- Pink:     #FF66CC
- Gray:     #AAAAAA
- White:    #FFFFFF
- Black:    #333333
```

### Control Buttons (Dark Gray Sidebars)
```
Top-Left:     [+👤] Add Player
Top-Right:    [123] Sort (low to high)
Bottom-Left:  [↻]  Reset all scores
Bottom-Right: [🔊] Toggle sound
```

---

## Technical Architecture

### Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Framework | **Vanilla JS** or **React** | Simple app, minimal deps |
| Styling | **CSS3** with CSS Variables | Theme support, animations |
| Storage | **localStorage** | Offline-first, no backend needed |
| Sound | **Web Audio API** | Low-latency sound effects |
| PWA | **Service Worker** | Installable, works offline |
| Future iOS | **Capacitor** | Wrap for App Store submission |

### Recommended: Vanilla JS + Modern CSS
Given the simplicity of the app, a vanilla JS approach with modern CSS keeps it lightweight and fast. No build step required for initial development.

### File Structure
```
scorekeeper/
├── index.html          # Single page app
├── css/
│   └── styles.css      # All styles with CSS variables
├── js/
│   ├── app.js          # Main app logic
│   ├── player.js       # Player class/module
│   ├── storage.js      # localStorage wrapper
│   └── sounds.js       # Audio handling
├── assets/
│   ├── sounds/         # Sound effect files
│   └── icons/          # App icons for PWA
├── manifest.json       # PWA manifest
└── sw.js              # Service worker for offline
```

---

## Data Model

### Player Object
```javascript
{
  id: "uuid-string",
  name: "Player 1",
  score: 0,
  color: "#E74C3C",
  createdAt: 1234567890,
  order: 0  // for manual sorting
}
```

### App State
```javascript
{
  players: [...],
  settings: {
    soundEnabled: true,
    sortMode: "manual" | "asc" | "desc",
    theme: "auto" | "light" | "dark"
  },
  version: 1  // for future migrations
}
```

---

## Implementation Phases

### Phase 1: Core MVP
**Goal: Basic functional scorekeeper with the killer feature (auto-sort)**

1. [ ] Set up HTML structure with semantic markup
2. [ ] Create CSS with mobile-first responsive design
3. [ ] **Responsive layout** - Works in both portrait AND landscape
4. [ ] Implement player list rendering
5. [ ] Add +/- buttons with tap handlers
6. [ ] Implement long-press for fast counting
7. [ ] Add player (with auto-assigned color)
8. [ ] Remove player
9. [ ] Edit player name (inline)
10. [ ] **Persistent localStorage** - Survives browser close, phone lock, app switch
11. [ ] Reset all scores
12. [ ] **Sort functionality** - THE killer feature (auto-rearrange leaders)

### Phase 2: Polish & UX
**Goal: Match Scorekeeper XL's satisfying UX**

1. [ ] Score change animations (number pop/scale)
2. [ ] Sound effects on score change
3. [ ] Sound toggle button
5. [ ] Smooth list reordering animations
6. [ ] Haptic feedback (where supported)
7. [ ] Color picker for players
8. [ ] Confirm dialog for reset/delete

### Phase 3: PWA & Offline
**Goal: Installable, works anywhere**

1. [ ] Create manifest.json with icons
2. [ ] Service worker for offline caching
3. [ ] "Add to Home Screen" prompt
4. [ ] Dark/light theme support
5. [ ] Viewport meta tags for native feel

### Phase 4: iOS App (Future)
**Goal: App Store submission**

1. [ ] Integrate Capacitor
2. [ ] Configure iOS project
3. [ ] Native haptics via Capacitor
4. [ ] Test on physical devices
5. [ ] App Store assets (screenshots, description)
6. [ ] Submit to App Store

---

## Key Interactions

### Score Increment/Decrement
```
Tap +/- button:
  1. Update score by ±1
  2. Play sound (if enabled)
  3. Animate score number (scale up briefly)
  4. Trigger haptic (if supported)
  5. Save to localStorage

Long press +/- button:
  1. After 500ms, start rapid increment
  2. Accelerate: 100ms intervals → 50ms → 25ms
  3. Play subtle "tick" sound per change
  4. On release, save to localStorage
```

### Add Player
```
Tap "+" button:
  1. Create new player with default name "Player N"
  2. Assign next available color
  3. Score starts at 0
  4. Animate in (slide down + fade)
  5. Auto-focus name field for editing
```

### Sort Toggle
```
Tap sort button:
  1. Cycle: Manual → Low-High → High-Low → Manual
  2. Animate reorder with smooth transitions
  3. Update icon to show current mode
```

---

## Accessibility (a11y)

- Semantic HTML (`<button>`, `<input>`, proper headings)
- ARIA labels for icon-only buttons
- Keyboard navigation support
- Sufficient color contrast (WCAG AA)
- Focus indicators
- Screen reader announcements for score changes

---

## Performance Targets

- **First Contentful Paint**: < 1s
- **Time to Interactive**: < 2s
- **Lighthouse Score**: > 90 (all categories)
- **Bundle Size**: < 50KB total (excluding sounds)

---

## Open Questions & Feature Requests

Based on App Store reviews, users requested these enhancements:

### High Priority (Consider for MVP)
1. **Custom increment size** - Set points per tap (3s, 7s, 10s for specific games)
2. ~~**Landscape mode**~~ - ✓ Now in MVP (responsive portrait + landscape)
3. **Less sensitive buttons** - Prevent accidental taps

### Medium Priority (Post-MVP)
4. **Save multiple games** - Come back and resume different games
5. **Player templates** - Save player groups for recurring game nights
6. **Undo feature** - Undo accidental score changes

### Lower Priority (Future)
7. **Timer** - Optional game timer
8. **Score history** - Track changes per player
9. **Custom color palette** - Beyond the 12 Atari colors

### Key User Sentiment (From Reviews)

**What users love:**
> "Simple, unobtrusive, and FAST"
> "No frills, no fuss, beautifully simple"
> "Slick... done with grace and style"
> "It legitimately DID NOT need updates, that's not a knock against it"
> "Most used app since my iPhone 3GS"

**Killer feature - auto-sorting:**
> "The leading team automatically appeared on top"
> "None (paid or free) had the option of automatically rearranging leaders after every round"
> "This one is what I was looking for" (differentiator from competitors)

**Large event usage:**
> "Used for youth event with 2,000 people - projected on huge screen"
> "Youth group Family Game Night... roughly 15 teams"
> "iPad + Apple TV + ScoreKeeper = Instant Score Board"

**Design Philosophy**: Keep it simple. The app was praised for NOT needing updates - simplicity is the feature. Add enhancements only if they don't complicate the core experience.

---

## Resources & References

- [Original Scorekeeper XL](https://apps.apple.com/us/app/scorekeeper-xl/id463243024) (no longer available)
- [AppAdvice - Scorekeeper XL](https://appadvice.com/app/scorekeeper-xl/463243024)
- Developer: Matt Rix

---

## Next Steps

1. **Review this plan** - Confirm scope and priorities
2. **Set up project structure** - Create files and folders
3. **Build Phase 1 MVP** - Core functionality first
4. **User testing** - Test on actual mobile devices
5. **Iterate on UX** - Refine based on feel
