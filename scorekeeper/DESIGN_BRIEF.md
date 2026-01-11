# Scorekeeper App - Design Brief

## What I Need
I'm building a mobile web app for tracking scores in board games (like Catan, Ticket to Ride, etc.). I'd love your design expertise to improve the visual design and UX. Please give me specific, actionable suggestions.

## Current State
The app is functional but feels generic. I want it to feel **fun, polished, and game-like** while staying **simple and fast to use**.

## What the App Does
- Track scores for 2-12 players in board games
- Each player has a name, color, and score
- Tap +/- buttons to adjust scores (long-press for rapid increment)
- Shows running total while adjusting ("0 + 10 = 10")
- Sort players by score, or restore original order
- Swipe left to delete, drag to reorder
- Sound effects and haptic feedback
- Works offline, installable as PWA

## Current Layout

### Top Toolbar
```
[Add Player]  [Undo]  [Sort/Unsort]
```

### Player Row (repeated for each player)
```
[⋮⋮] PLAYER NAME          5 + 3 = 8  [-] [+]
     (drag)               (running total) (buttons)
```
- Full-width colored background per player
- Text color auto-adjusts (black on light, white on dark)

### Bottom Toolbar
```
[Reset Scores]  [Sound On/Off]
```

### Empty State (no players yet)
- Full-screen green gradient button
- Big icon + "Tap to Add Your First Player"

## Color Palette
12 Atari-style colors: Red, Orange, Yellow, Green, Lime, Cyan, Blue, Purple, Pink, Gray, Black, White

## Design Questions for You

### 1. Overall Visual Style
- What visual style would make this feel more "game-like" and fun?
- Should I add texture, gradients, shadows, or keep it flat?
- Any specific design systems or apps I should look at for inspiration?

### 2. Player Rows
- How can I make the player rows more visually interesting?
- Should I add icons, avatars, or visual flourishes?
- How do I make the drag handle more discoverable without cluttering?

### 3. Score Display
- The score is the most important element. How can I emphasize it more?
- The running total ("5 + 3 = 8") appears briefly - any ideas to make this more delightful?

### 4. Buttons & Interactions
- The +/- buttons are plain. How can I make them more satisfying to tap?
- Should they have different states (pressed, disabled, etc.)?

### 5. Empty State & Onboarding
- Currently just a big green button. Ideas for making first-run more welcoming?
- Should I add a brief tutorial or coach marks?

### 6. Toolbar Design
- Top/bottom toolbars are basic gray. How can I improve them?
- Icon-only vs icon+label debate - what works better for discoverability?

### 7. Animation & Microinteractions
- Currently have: score bump animation, sort slide-in, ta-dah sound
- What other animations would add delight without slowing things down?

### 8. Dark Mode / Theming
- Currently dark background only. Worth adding light mode?
- Should players be able to choose themes?

### 9. Typography
- Using system fonts. Should I use a custom font for a more distinctive feel?
- What font would feel both playful and readable?

### 10. Accessibility
- Text contrast is auto-calculated. Anything else I should consider?
- The drag handle is subtle - is that a problem?

## Constraints
- Must work on phones in both portrait and landscape
- Must be fast and responsive (this is used during live gameplay)
- Can't require login or internet after first load
- Target users: casual board gamers, families, game nights

## What Format I Want
Please give me:
1. **Specific visual recommendations** (colors, spacing, typography, etc.)
2. **Mockup descriptions** or ASCII layouts if helpful
3. **CSS property suggestions** where applicable
4. **References** to existing apps or design systems I could learn from

Don't hold back - I want to make this really good!
