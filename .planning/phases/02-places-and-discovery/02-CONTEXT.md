# Phase 2: Places and Discovery - Context

**Gathered:** 2026-02-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can find, browse, and navigate to real nearby pizza places. A horizontal snap-to-card carousel shows nearby places, drives the compass target, expands for details, and hands off to a navigation app. Includes infinite loading, live distance updates, and empty/error states. Design system and personality features (mystery mode, onboarding) are Phase 3.

</domain>

<decisions>
## Implementation Decisions

### Card content and layout
- Collapsed card shows: name, distance (in pizza slices), and star rating
- Distance displayed in pizza slices (~8 inches per slice), always — commit to the bit regardless of number size (e.g., "2,134 slices away")
- No real-unit fallback — pizza slices are the only distance unit
- Expanded card adds: address, hours, rating, directions button, plus whatever else MKLocalSearch provides that's useful (Claude's discretion on expanded layout)

### Carousel interaction feel
- Cards float as a translucent overlay strip over the compass — compass gets full screen behind them
- One centered card visible at a time — neighbors barely peek from edges
- Snapping to a new card triggers an animated compass swing from old target to new (physical instrument feel, not instant jump)
- Card expand: grows in place upward over the compass, tap again to collapse — no sheet or modal

### Directions handoff
- Directions button lives on the expanded card only (two-step: tap to expand, then tap directions)
- Ask user once which maps app to use (Google Maps or Apple Maps), remember the choice — changeable later
- No confirmation dialog before leaving the app — tap directions, immediately opens maps
- Deep link requests walking directions by default — pizza is a walking-distance food

### Claude's Discretion
- Expanded card detail layout and which MKLocalSearch fields to include beyond address/hours/rating
- Card translucency level and visual treatment of the overlay strip
- Exact snap animation timing and spring parameters
- Loading skeleton design for cards
- Error state messaging and visual treatment
- Where/how the maps app preference is stored and changed

</decisions>

<specifics>
## Specific Ideas

- Distance in pizza slices is a core personality feature — ~8 inches per slice, displayed as integer count with commas ("2,134 slices away"), no real-unit fallback
- Compass swing on card snap should feel like a physical instrument — weighted, not robotic
- Cards overlay the compass rather than splitting the screen — the compass is always the star

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-places-and-discovery*
*Context gathered: 2026-02-21*
