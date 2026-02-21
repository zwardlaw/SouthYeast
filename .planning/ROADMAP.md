# Roadmap: SouthYeast

## Overview

SouthYeast is built in three phases: first, a compass that points correctly at pizza with all the infrastructure to support it; second, real places data flowing through a scrollable card carousel; third, the neobrutalist visual identity and personality features that make the app worth shipping. Mechanics are validated before aesthetics are applied — wrong values with beautiful animations are worse than correct values with placeholder styling.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Compass Core** - Project scaffold, location permission state machine, and mathematically correct compass rotation
- [ ] **Phase 2: Places and Discovery** - Real pizza places via MKLocalSearch, snap-to-card carousel, and directions handoff
- [ ] **Phase 3: Design and Personality** - Neobrutalist design system, mystery mode, onboarding, and haptic + animation polish

## Phase Details

### Phase 1: Compass Core
**Goal**: The compass points at real pizza and stays correct as the user moves and rotates
**Depends on**: Nothing (first phase)
**Requirements**: INFR-01, INFR-02, INFR-04, INFR-05, INFR-06, COMP-01, COMP-02, COMP-04, COMP-05
**Success Criteria** (what must be TRUE):
  1. App requests location permission with a priming screen before the system dialog appears
  2. Compass needle rotates to track pizza as the user physically turns their phone — needle stays pointed at the target, not at a fixed map direction
  3. Compass displays a calibration state instead of garbage data when heading accuracy is unreliable
  4. Selecting a different place in the carousel causes the compass to immediately re-target
  5. App resumes correct heading on foreground restore after backgrounding
**Plans**: TBD

Plans:
- [ ] 01-01: Project scaffold — Swift 6 / SwiftUI target, PrivacyInfo.xcprivacy, app lifecycle wiring
- [ ] 01-02: LocationService — CLLocationManager @Observable wrapper, permission state machine, heading + GPS publishing
- [ ] 01-03: Compass math and view — bearing calculation, 0/360 wrap handling, trueHeading subtraction, calibration state, CompassView with rotation

### Phase 2: Places and Discovery
**Goal**: Users can find, browse, and navigate to real nearby pizza places
**Depends on**: Phase 1
**Requirements**: DISC-01, DISC-02, DISC-03, DISC-04, DISC-05, DISC-06, INFR-03, COMP-03
**Success Criteria** (what must be TRUE):
  1. A horizontal scrollable carousel shows real nearby pizza places sorted closest-first, with name and distance on each card
  2. Snapping to a card repoints the compass at that place
  3. Tapping a card expands it to show address, hours, and rating
  4. Tapping directions opens Google Maps (with Apple Maps fallback) and begins turn-by-turn navigation
  5. Scrolling near the end of the list loads additional places automatically
  6. Distance values on cards update as the user moves through the city
  7. Empty state and error states (no internet, no pizza nearby, location denied) display useful messages instead of blank screens
**Plans**: TBD

Plans:
- [ ] 02-01: PlacesService — MKLocalSearch integration, Place value type, batch loading, 50m re-query threshold
- [ ] 02-02: CarouselView — snap-to-card scrollTargetBehavior, card expand, directions handoff, empty/error states, haptic pulse on compass alignment

### Phase 3: Design and Personality
**Goal**: The app looks and feels like SouthYeast — bold, physical, and surprising
**Depends on**: Phase 2
**Requirements**: PERS-01, PERS-02, PERS-03, PERS-04, PERS-05
**Success Criteria** (what must be TRUE):
  1. Every screen uses the neobrutalist design system — thick borders, hard shadows, bold typography, and pizza color palette applied consistently
  2. The compass needle is a custom pizza slice shape that feels like a physical instrument, not a generic arrow
  3. Mystery mode hides all restaurant names throughout the app when activated via the leftmost card
  4. First-time users see an onboarding screen that explains the compass concept and mystery mode before they see the main UI
  5. Location permission is preceded by a priming screen that explains why the app needs location access
**Plans**: TBD

Plans:
- [ ] 03-01: DesignSystem — color tokens, typography, spacing, border/shadow ViewModifiers (.nbCard, .nbButton), pizza slice Shape
- [ ] 03-02: Personality features — mystery mode toggle, onboarding flow, location priming screen, spring micro-animations throughout

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Compass Core | 0/3 | Not started | - |
| 2. Places and Discovery | 0/2 | Not started | - |
| 3. Design and Personality | 0/2 | Not started | - |
