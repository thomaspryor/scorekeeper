# Scorekeeper — Project Rules

## Stack
- Vanilla HTML/CSS/JS — no frameworks, no build step, no dependencies
- PWA with offline support (manifest.json + service worker)
- All source files live in `/docs`

## Architecture
- `docs/index.html` — single-page app entry
- `docs/app.js` — all game logic, UI, state management (~1,200 lines)
- `docs/styles.css` — all styles (~760 lines)
- `docs/manifest.json` — PWA manifest

## Deployment
- **Domain:** scorekeep.co
- **Host:** Vercel (connected to GitHub repo `thomaspryor/scorekeeper`)
- **Root directory:** `docs`
- Auto-deploys on push to `master`

## Design Principles
- Mobile-first — designed for phone use during games
- No accounts, no server — all data in localStorage
- Fast, tactile interactions (haptics, sounds, swipe gestures)
- Must work offline reliably
