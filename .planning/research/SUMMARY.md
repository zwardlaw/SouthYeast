# Project Research Summary

**Project:** SouthYeast — Neobrutalist iOS Pizza Compass
**Domain:** iOS single-purpose location instrument / novelty food-finder app
**Researched:** 2026-02-21
**Confidence:** HIGH

## Executive Summary

SouthYeast is best understood as a novelty instrument app with a restaurant discovery side-effect — not a food-finding utility. The closest analogs are hardware compass gadgets and single-purpose iPhone instrument apps, not Yelp or Google Maps. Research consistently confirms that the app's competitive moat is the quality of the gag (a pizza slice that spins correctly, looks bold, and surprises users with mystery mode), not feature breadth. Every architectural and feature decision should be evaluated against the question "does this serve the joke?" rather than "does this match restaurant-app conventions."

The recommended technical approach is zero third-party dependencies using only Apple's native iOS 17 stack: Swift 6, SwiftUI, Core Location, and MapKit. This is not a compromise — it is the right architecture. `CLLocationManager` with `@Observable` wrapping delivers heading and GPS natively without libraries. `MKLocalSearch` delivers pizza places for free with no API key. `MKMapItem.openInMaps()` handles directions handoff in one line. If MKLocalSearch data quality proves insufficient in target markets, a clearly-scoped escalation path to Google Places SDK v10.8.0 (SPM) exists and was fully researched.

The single highest-risk area is the compass rotation mechanics. Three interdependent bugs — the 0/360 degree wrap causing full-circle spins near north, the missing `bearing - deviceHeading` subtraction that makes the compass point at a fixed map direction instead of relative to the user, and the `magneticHeading` vs `trueHeading` mismatch — are all present in nearly every first-pass compass implementation. These must be addressed in the first phase, before any UI polish work, because they are invisible during development (when the developer faces one direction) and catastrophic in user testing. The architecture research prescribes a specific solution for all three.

## Key Findings

### Recommended Stack

The app can ship with **zero third-party dependencies** using only Apple frameworks: Swift 6 / SwiftUI (iOS 17 minimum, built against iOS 18 SDK per App Store requirements), Core Location for heading + GPS, MapKit for place search and directions handoff. The `@Observable` macro (iOS 17) replaces `ObservableObject + @Published` and is critical for performance: heading updates arrive at 10-20 Hz, and `@Observable`'s selective property tracking prevents the cascade re-renders that `ObservableObject` triggers. SPM is the only supported dependency manager (CocoaPods entered maintenance mode August 2025).

**Core technologies:**
- **Swift 6 / SwiftUI (iOS 17+):** Primary language and UI framework — native, required for `@Observable`, `scrollTargetBehavior`, and `CLLocationUpdate.liveUpdates()`
- **Core Location (CLLocationManager):** Heading + GPS — no third-party wrapper needed; delegate pattern wraps cleanly into `@Observable`
- **MapKit (MKLocalSearch):** Pizza place search — free, no API key, private, native Apple Maps directions handoff
- **@Observable macro:** State management — selective re-rendering critical for high-frequency heading updates
- **SwiftUI `.interpolatingSpring`:** Compass animation — stiffness 170, damping 26 produces physical compass feel
- **SwiftUI `scrollTargetBehavior(.viewAligned)`:** Snap-to-card carousel — iOS 17 native, no library needed
- **Google Places SDK v10.8.0 (SPM):** Fallback only — activate if MKLocalSearch result quality fails in target markets

### Expected Features

SouthYeast's table stakes are defined by the core mechanic, not restaurant-app conventions. The app must do one thing perfectly: open, find pizza, point at it.

**Must have (table stakes):**
- Location permission priming screen — context before the system dialog; users who don't understand the gag deny location
- Compass pointing correctly at nearest pizza — bearing math + heading subtraction; wrong = trust destroyed immediately
- Smooth pizza slice rotation — animation is load-bearing; jitter reads as broken
- Real pizza places (not stale) — users will check; fake or closed results kill the joke
- Distance shown on cards — users need to know if "nearest" is 0.2 mi or 12 mi
- Card expand with address, hours, rating — minimum detail for someone who commits to going
- Apple Maps directions handoff — `MKMapItem.openInMaps()` in one line; users expect it
- Empty state + location-denied state — graceful failure is required for App Store approval

**Should have (differentiators — high value, relatively low cost):**
- Pizza slice compass needle — the central visual gag; custom SwiftUI `Shape`, must feel physical
- Mystery mode — single leftmost card toggle; hides names throughout; defines the product's personality
- Neobrutalist design (thick borders, hard shadows, bold type, pizza colors) — aesthetic coherence; half-done neobrutalism looks cheap
- Haptic pulse on compass alignment — makes the instrument feel real; `UIImpactFeedbackGenerator`
- Polished spring micro-animations — timing IS the product; SwiftUI spring physics throughout

**Defer (v2+):**
- Infinite scroll / pagination — MKLocalSearch is limited to ~10-25 results; load 20 upfront for MVP; add pagination only if users want more
- Onboarding flow — add only if early users don't understand mystery mode
- "Getting warm" proximity signal — nice polish, but needs distance delta tracking; v1.1
- Custom display font — SF Pro Black achieves neobrutalist boldness without App Store complications; defer custom font to v2

**Anti-features (deliberately excluded):**
- User accounts, saved lists, reviews, social features, in-app ordering, dark mode, offline mode, cuisine filtering beyond pizza, push notifications, map view

### Architecture Approach

Service-layer MVVM with `@Observable` services injected via SwiftUI `@Environment` is the correct pattern for this app's single-screen, real-time data stream architecture. No coordinator needed (single screen). No TCA needed (complexity is in data streams, not navigation state). The separation is: `LocationService` owns the CLLocationManager and publishes `location` and `heading`; `PlacesService` executes MKLocalSearch queries and owns the `[Place]` array; `AppState` composes both services and derives `compassAngle = bearing(to: selectedPlace) - locationService.heading`. `CompassView` only reads `AppState.compassAngle` and renders — no business logic in views.

**Major components:**
1. **LocationService** (`@Observable`) — wraps one `CLLocationManager` instance; publishes location and heading; never instantiated more than once
2. **PlacesService** (`@Observable`) — executes MKLocalSearch queries; maps `MKMapItem` → `Place` value types; owns the places array
3. **AppState** (`@Observable`) — derives `compassAngle` from heading + bearing; holds `selectedPlace`, `mysteryMode`, `permissionStatus`; the composition layer, not a god object
4. **CompassView** — reads `AppState.compassAngle`; applies `rotationEffect` + `interpolatingSpring`; no math
5. **CarouselView** — horizontal `LazyHStack` with `scrollTargetBehavior(.viewAligned)`; reads `PlacesService.places`
6. **DesignSystem** — static tokens (colors, typography, spacing, border widths) + `ViewModifiers` (`.nbCard()`, `.nbButton()`)
7. **SouthYeastApp** — bootstraps services, injects via `.environment()`; never a singleton anti-pattern

Build order is strictly layered: DesignSystem + Place model first (no dependencies) → LocationService + PlacesService → AppState + bearing math → CompassView + CarouselView → ContentView wiring.

### Critical Pitfalls

1. **0/360 degree wrap — compass spins full circle through north** — Track heading as monotonically-accumulated value (apply deltas), never normalize to 0-360 for animation; unit test: 350 → 10 degrees should animate 20 degrees forward, not 340 backward. Address in Phase 1 before any animation polish.

2. **Missing `bearing - deviceHeading` subtraction** — Bearing from coordinates gives a fixed map direction; subtracting device heading makes it relative to where the user faces. The slice must rotate WITH the user's phone rotation to stay pointing at the pizza. Address in Phase 1 compass core logic.

3. **`magneticHeading` vs `trueHeading` mismatch** — Bearing formula returns true north degrees; using `magneticHeading` introduces systematic 15-20 degree error (varies by city). Always use `trueHeading`; requires `startUpdatingLocation()` to be running simultaneously. Address in Phase 1.

4. **`headingAccuracy` not gated** — `CLHeading.headingAccuracy < 0` means invalid reading; displaying garbage on launch indoors destroys trust immediately. Gate compass display on accuracy; enable the iOS calibration figure-eight prompt. Address in Phase 1.

5. **Privacy manifest missing — App Store rejection** — `PrivacyInfo.xcprivacy` required for all submissions using Core Location (since May 2024; ~12% of submissions rejected Q1 2025). Scaffold the file at project setup, not at submission time.

## Implications for Roadmap

Based on the architecture's layer dependency map and the pitfall severity analysis, research suggests a 4-phase structure where the compass mechanics are fully validated before any UI polish work begins, and where data infrastructure is confirmed before feature layering.

### Phase 1: Core Infrastructure and Compass Mechanics

**Rationale:** Everything depends on location permission and correct compass rotation. Three critical pitfalls (0/360 wrap, heading subtraction, trueHeading mismatch) must be resolved before any UI work begins — they are invisible during development and catastrophic in testing. Architecture's Layer 0 and Layer 1 must precede all other work.

**Delivers:** Working compass needle (pizza slice or placeholder) that correctly tracks the nearest pizza from any direction, with location permission state machine handling all 5 authorization states.

**Addresses features:** Location permission priming, compass bearing calculation, heading accuracy gating, `PrivacyInfo.xcprivacy` scaffold.

**Avoids pitfalls:** 0/360 wrap (Pitfall 1), heading subtraction (Pitfall 2), headingAccuracy gate (Pitfall 3), permission denied state (Pitfall 4), privacy manifest (Pitfall 5), multiple CLLocationManager instances (Pitfall 13), race conditions at launch (Pitfall 10).

**Stack used:** Swift 6, SwiftUI, Core Location (`CLLocationManager`, `CLHeading`, `CLLocationUpdate.liveUpdates()`), `@Observable`.

**Research flag:** Standard, well-documented patterns. No additional research-phase needed, but unit tests of bearing math are non-negotiable.

### Phase 2: Places Discovery and Carousel

**Rationale:** With a confirmed working compass, wire in real places data. MKLocalSearch integration is the data foundation for the entire app. The `Place` value type and `PlacesService` are already scoped in the architecture. Carousel belongs in this phase because it requires real data to validate scroll behavior and card design.

**Delivers:** Horizontal snap-to-card carousel populated with real nearby pizza places (name, distance), compass retargeting on card tap, Apple Maps directions handoff, empty state and error state UI.

**Addresses features:** Real pizza places with current status, distance on cards, carousel with snap behavior, card expand (address, hours, rating), Apple Maps handoff, empty/error states.

**Avoids pitfalls:** Unbounded Places queries (Pitfall 7 — cache results, 50m re-query threshold), empty results (Pitfall 11 — radius expansion + empty state), battery drain (Pitfall 6 — `distanceFilter`, `desiredAccuracy` tuned).

**Stack used:** MapKit (`MKLocalSearch`, `MKMapItem.openInMaps()`), SwiftUI `ScrollView` + `LazyHStack` + `scrollTargetBehavior(.viewAligned)`.

**Research flag:** Standard patterns. MKLocalSearch data quality is the one unverified risk — test in target markets early. If quality is poor, the Google Places escalation path is fully researched (SDK v10.8.0, SPM, pricing confirmed).

### Phase 3: Neobrutalist Design System and Personality Features

**Rationale:** With working data and mechanics, implement the visual identity and the features that define SouthYeast's personality. The DesignSystem is Layer 0 in the architecture (no dependencies), so it can be built in parallel with Phase 1-2 or applied here as a full-pass replacement of placeholder styling. Mystery mode is a display-only flag (no new data path) and belongs alongside the design pass. Haptics are low-effort, high-personality.

**Delivers:** Consistent neobrutalist visual design across all screens, mystery mode toggle, haptic feedback on compass alignment, polished spring micro-animations throughout.

**Addresses features:** Pizza slice compass needle (custom SwiftUI `Shape`), neobrutalist design system (border tokens, hard shadows, pizza color palette, bold typography), mystery mode, haptic pulse on alignment, spring animations.

**Avoids pitfalls:** Heading jitter / low-pass filter (Pitfall 8 — apply here during animation polish pass), accessibility (Pitfall 14 — `accessibilityLabel` on compass).

**Stack used:** SwiftUI custom `Shape` + `Path`, `rotationEffect` + `interpolatingSpring`, `UIImpactFeedbackGenerator`, DesignSystem `ViewModifiers` (`.nbCard()`, `.nbButton()`).

**Research flag:** Neobrutalism token values (border width, shadow offset, color palette) require design iteration. The design system implementation approach is well-documented, but specific values are not "right or wrong" — they need visual testing. Consider a dedicated design review before this phase is finalized.

### Phase 4: Polish, App Lifecycle, and App Store Preparation

**Rationale:** Final phase addresses the remaining moderate pitfalls (foreground/background heading state, accessibility) and the App Store submission requirements. This phase has no feature dependencies on earlier phases — it can be partially parallelized with Phase 3.

**Delivers:** App lifecycle handling (foreground transition resets stale heading), accessibility annotations on compass, VoiceOver testing, Dynamic Type validation, complete `PrivacyInfo.xcprivacy` with all declared data uses, App Store submission.

**Addresses features:** App Store deployment, accessibility compliance, lifecycle correctness.

**Avoids pitfalls:** Stale heading after backgrounding (Pitfall 12), neobrutalist accessibility break (Pitfall 14), privacy manifest rejection (Pitfall 5 — finalize what was scaffolded in Phase 1).

**Research flag:** No additional research needed. Standard App Store submission process.

### Phase Ordering Rationale

- **Mechanics before aesthetics:** The compass must work correctly before visual polish is applied. Animating the wrong values with beautiful spring physics is worse than correct values with no animation.
- **Data before features:** Mystery mode, haptics, and polish layers all depend on real places data flowing through the system. Phases 1-2 create that foundation before Phase 3 builds on it.
- **DesignSystem as parallel track:** The DesignSystem (Layer 0 in architecture) has zero runtime dependencies and can be authored in parallel with Phases 1-2, then applied in Phase 3. If resources allow, this reduces total timeline.
- **Pitfall-driven ordering:** The three highest-severity pitfalls (compass rotation correctness) all land in Phase 1. Placing them first means any fundamental mechanical error is discovered with minimal sunk cost in UI or polish.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Places):** MKLocalSearch data quality in target markets is the single unverified assumption. Validate early in development with real device testing in the app's primary geography. If quality is insufficient, the Google Places escalation path is already fully researched — the decision tree is clear.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Compass mechanics):** Well-documented Apple APIs; bearing math is established trigonometry; pitfalls are known and solutions are provided in PITFALLS.md and ARCHITECTURE.md.
- **Phase 3 (Design system):** Design tokens require iteration, not research. Implementation patterns are standard SwiftUI.
- **Phase 4 (App Store):** Submission process is standard. Privacy manifest requirements are documented.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Core Apple APIs verified via official documentation. Google Places pricing verified from official docs (v10.8.0, Jan 2026). CocoaPods maintenance mode confirmed from Google's own release notes. |
| Features | HIGH | Feature categorization grounded in clear analogues (Pizza Compass hardware device, FoodCompass app). Anti-features are well-reasoned against scope and philosophy, not arbitrary. |
| Architecture | HIGH | Pattern sourced from Apple official docs and multiple HIGH-confidence tutorials. Component boundaries, data flows, and anti-patterns are specific and actionable. Bearing math formula is standard spherical trigonometry. |
| Pitfalls | HIGH for compass/location mechanics; MEDIUM for places API cost patterns | Compass rotation pitfalls confirmed across multiple independent compass implementations and Apple docs. Google Places pricing restructure (March 2025) confirmed from official pricing page, but pricing can change. |

**Overall confidence:** HIGH

### Gaps to Address

- **MKLocalSearch result quality:** Confirmed as a recognized limitation (10-25 results, data quality varies by region) but actual quality in target US markets is only verifiable with a live device test. If SouthYeast targets a specific city for launch, validate MKLocalSearch results in that city before committing to MapKit as the permanent backend.

- **Haptic design specifics:** Research confirms `UIImpactFeedbackGenerator` as the right tool and "pulse when aligned" as the right behavior. The exact haptic pattern (intensity, rhythm, alignment threshold in degrees) is a design/feel question that requires on-device tuning, not further research.

- **Neobrutalist color palette:** Research identifies the token structure (border: 3-4pt, shadow: hard offset no-blur, corners: 0-4pt) but the specific pizza color palette (reds, oranges, creams) requires visual design iteration. Not a research gap — a design execution question.

- **MKLocalSearch pagination absence:** MKLocalSearch does not support cursor-based pagination (research confirmed). For MVP this is acceptable (load 20 results upfront). If user testing shows strong demand for more results, the Google Places migration path is the correct response, not a MapKit workaround.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: CLLocationManager, CLHeading, CLLocationUpdate.liveUpdates(), MKLocalSearch, MKPointOfInterestCategory, @Observable migration guide, PrivacyInfo.xcprivacy, App Store SDK requirements
- Google: Places SDK for iOS v10.8.0 release notes (January 27, 2026); CocoaPods maintenance mode announcement (August 2025); Places SDK pricing tiers (Pro/Enterprise/Enterprise Plus)
- Apple Developer: MKMapItem.openInMaps(), scrollTargetBehavior documentation

### Secondary (MEDIUM confidence)
- WWDC23 coverage: CLLocationUpdate.liveUpdates(), iOS 17 scrollTargetBehavior
- GetStream SwiftUI spring animation guide (interpolatingSpring parameters)
- Five Stars blog: Compass app in Swift (verified against CoreLocation docs)
- Create with Swift: MKLocalSearch with SwiftUI (verified with Apple docs)
- Hacking with Swift: @Observable environment injection
- GetStream: iOS 17 scrollTargetBehavior implementation (multiple consistent sources)
- NNGroup: Neobrutalism design principles; Mobile carousels
- Medium (Simform Engineering): WWDC23 CLLocationUpdate
- BiTE Interactive: Rotation animation normalization

### Tertiary (LOW confidence)
- Medium: Ultimate Guide to Modern iOS Architecture 2025 (not verified against official docs)

---
*Research completed: 2026-02-21*
*Ready for roadmap: yes*
