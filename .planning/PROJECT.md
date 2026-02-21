# SouthYeast

## What This Is

A neobrutalist iOS app that uses your location to find the nearest pizza and points you to it with a rotating pizza slice compass. Bottom carousel lets you browse nearby spots, tap for details, or go mystery mode and just trust the slice.

## Core Value

The pizza slice compass always points to the nearest pizza. Open the app, find pizza. That's it.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Real-time pizza slice compass that rotates to point at the selected pizza place
- [ ] Location services integration for user's current position
- [ ] Google/Apple Maps Places API for pizza place data
- [ ] Horizontal scrolling card carousel at bottom of screen (closest on left)
- [ ] Cards show pizza place name, distance, and basic info
- [ ] Tap card to expand for more details (hours, rating, address)
- [ ] Tap for directions opens Apple Maps with turn-by-turn
- [ ] Infinite scroll: loads closest 10, auto-loads 10 more near end of list
- [ ] Compass re-targets when user selects a different card
- [ ] Mystery mode: 🫣 card at far left, tap to hide restaurant names — just compass + distance
- [ ] Neobrutalist visual design inspired by notboring.co (bold, thick borders, strong colors)
- [ ] Smooth compass animation (pizza slice rotates fluidly, not jumpy)
- [ ] Onboarding flow for first-time users
- [ ] Polished animations and transitions throughout

### Out of Scope

- Android version — iOS only for v1
- User accounts / login — no need, it's a compass
- Reviews or ratings system — just surface existing data from Maps API
- Social features / sharing — not core to the compass experience
- Saved / favorite places — keep it ephemeral, trust the slice
- In-app ordering — this finds pizza, it doesn't sell pizza

## Context

- Fun side project — an old idea that's now feasible to build with AI
- Neobrutalist design language: thick outlines, bold typography, high contrast colors, slightly raw/unpolished-on-purpose aesthetic. Reference: notboring.co apps
- The compass is the star — it should feel physical, satisfying, almost like a real instrument
- Mystery mode is the personality of the app — the idea that you just trust a pizza slice to guide you

## Constraints

- **Platform**: iOS (Swift/SwiftUI) — native only
- **Data source**: Google Places API or Apple MapKit for pizza place search — needs reliable, up-to-date restaurant data
- **Location**: Requires continuous location access for compass accuracy
- **Cost**: Google Places API has usage costs — need to manage query volume (batch loading 10 at a time helps)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Neobrutalist design | User vision, inspired by notboring.co | — Pending |
| Google/Apple Maps for data | Reliable, comprehensive pizza place coverage | — Pending |
| Mystery mode via leftmost card | Natural discovery through scrolling, not buried in settings | — Pending |
| Infinite scroll with batch loading | Keeps initial load fast, feels endless | — Pending |

---
*Last updated: 2026-02-21 after initialization*
