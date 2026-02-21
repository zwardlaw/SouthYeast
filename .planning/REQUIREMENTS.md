# Requirements: Take Me to Pizza

**Defined:** 2026-02-21
**Core Value:** The pizza slice compass always points to the nearest pizza. Open the app, find pizza.

## v1 Requirements

### Compass

- [x] **COMP-01**: Pizza slice pointer rotates to point at the currently selected pizza place
- [x] **COMP-02**: Smooth spring-based rotation animation with correct 0/360 wrap handling
- [ ] **COMP-03**: Haptic pulse when compass aligns with target direction
- [x] **COMP-04**: Calibration state shown when heading data is unreliable (headingAccuracy < 0)
- [x] **COMP-05**: Compass re-targets when user selects a different card in the carousel

### Discovery

- [ ] **DISC-01**: Horizontal scrolling card carousel at bottom of screen, closest place on left
- [ ] **DISC-02**: Cards show pizza place name, distance, and basic info
- [ ] **DISC-03**: Tap card to expand showing details (hours, rating, address)
- [ ] **DISC-04**: Tap for directions opens Google Maps (preferred) with Apple Maps fallback
- [ ] **DISC-05**: Infinite scroll: loads closest 10, auto-loads 10 more near end of list
- [ ] **DISC-06**: Distance display updates as user moves

### Personality

- [ ] **PERS-01**: Mystery mode activated via 🫣 card at far left of carousel
- [ ] **PERS-02**: Mystery mode hides restaurant names, shows only compass + distance
- [ ] **PERS-03**: Onboarding flow for first-time users explaining the concept
- [ ] **PERS-04**: Neobrutalist design system (thick borders, bold typography, strong colors)
- [ ] **PERS-05**: Location permission priming screen before iOS system prompt

### Infrastructure

- [x] **INFR-01**: Location permission state machine handling all states (authorized, denied, restricted, not determined)
- [x] **INFR-02**: Privacy manifest (PrivacyInfo.xcprivacy) for App Store compliance
- [ ] **INFR-03**: Error states: no internet, no pizza nearby, location denied
- [x] **INFR-04**: App lifecycle: foreground/background transitions, compass resume
- [x] **INFR-05**: iOS 17+ deployment target, Swift 6, SwiftUI
- [ ] **INFR-06**: MKLocalSearch for place data (free, no API key), Google Places as escalation path

## v2 Requirements

### Enhanced Discovery

- **DISC-V2-01**: Filter by pizza type (New York, Detroit, Neapolitan, etc.)
- **DISC-V2-02**: User ratings / favorites
- **DISC-V2-03**: Google Places API integration for richer data

### Social

- **SOCL-V2-01**: Share pizza compass screenshot
- **SOCL-V2-02**: Share mystery mode results ("I trusted the slice and found...")

### Platform

- **PLAT-V2-01**: Widget showing nearest pizza distance
- **PLAT-V2-02**: Apple Watch companion (compass on wrist)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Map view | Violates core concept — this is a compass, not a map app |
| User accounts / login | No need, it's a compass |
| In-app ordering | This finds pizza, it doesn't sell pizza |
| Dark mode | Neobrutalist design is intentionally bold; dark mode dilutes identity |
| Notifications | Nothing to notify about — open when hungry |
| Offline caching | Compass needs live location; stale place data has no value |
| Android | iOS only for v1 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| COMP-01 | Phase 1 | Complete |
| COMP-02 | Phase 1 | Complete |
| COMP-03 | Phase 2 | Pending |
| COMP-04 | Phase 1 | Complete |
| COMP-05 | Phase 1 | Complete |
| DISC-01 | Phase 2 | Pending |
| DISC-02 | Phase 2 | Pending |
| DISC-03 | Phase 2 | Pending |
| DISC-04 | Phase 2 | Pending |
| DISC-05 | Phase 2 | Pending |
| DISC-06 | Phase 2 | Pending |
| PERS-01 | Phase 3 | Pending |
| PERS-02 | Phase 3 | Pending |
| PERS-03 | Phase 3 | Pending |
| PERS-04 | Phase 3 | Pending |
| PERS-05 | Phase 3 | Pending |
| INFR-01 | Phase 1 | Complete |
| INFR-02 | Phase 1 | Complete |
| INFR-03 | Phase 2 | Pending |
| INFR-04 | Phase 1 | Complete |
| INFR-05 | Phase 1 | Complete |
| INFR-06 | Phase 2 | Pending |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0

---
*Requirements defined: 2026-02-21*
*Last updated: 2026-02-21 after Phase 1 completion*
