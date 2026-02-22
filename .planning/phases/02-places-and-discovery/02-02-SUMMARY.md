---
phase: 02-places-and-discovery
plan: 02
subsystem: ui
tags: [swiftui, carousel, mapkit, haptics, scroll, appstate, networkmonitor, swift6, directions]

# Dependency graph
requires:
  - phase: 02-places-and-discovery/02-01
    provides: PlacesService, NetworkMonitor, Place model, AppState.isAligned — data layer this UI consumes
  - phase: 01-compass-core
    provides: CompassView, AppState, LocationService, BearingMath — compass mechanics carousel overlays
provides:
  - CarouselView: snap-to-card horizontal ScrollView with peek edges overlaying the compass
  - CardView: collapsed (name + pizza-slice distance) and expanded (address, phone, website, directions)
  - openDirections: Google Maps / Apple Maps deep link handoff with walking mode
  - Maps app preference stored via @AppStorage, asked once via confirmationDialog
  - Empty, offline, error, and loading skeleton states for all PlacesService conditions
  - CompassView rewritten as ZStack with CarouselView at bottom (PlacePickerRow removed)
  - ContentView place fetching: initial load on first location fix, distance updates on 50m movement
  - NetworkMonitor injected through entire environment tree via TakeMeToPizzaApp
  - Haptic feedback on compass alignment via .sensoryFeedback on needle Image
affects:
  - 03-design-and-personality (will restyle CarouselView/CardView with neobrutalist design system)
  - phase 3 Phase custom pizza-slice compass needle (CompassView ZStack structure preserved)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ZStack(alignment: .bottom) for compass-behind, carousel-overlay layout"
    - "@AppStorage for cross-session preference persistence (maps app choice)"
    - "GeometryReader cardWidth = totalWidth - 80 for peek edges"
    - ".scrollTargetBehavior(.viewAligned) + .scrollPosition(id:) for snap-to-card"
    - ".sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7)) triggered by Bool toggle"
    - "isUserScrolling guard on onChange(of: scrollID) to prevent programmatic re-entrancy"
    - "onChange(of: locationService.location) for reactive place fetching and distance updates"
    - ".task modifier on CompassView case for initial fetch when location pre-authorized"
    - "@MainActor on free function openDirections() for UIApplication.shared access"

key-files:
  created:
    - TakeMeToPizza/Views/CarouselView.swift
  modified:
    - TakeMeToPizza/Views/CompassView.swift
    - TakeMeToPizza/ContentView.swift
    - TakeMeToPizza/TakeMeToPizzaApp.swift
    - TakeMeToPizza.xcodeproj/project.pbxproj

key-decisions:
  - "CarouselView peek: cardWidth = proxy.size.width - 80 (40pt each side), centered via .padding(.horizontal, sideInset)"
  - "Expand animation: .spring(response: 0.35, dampingFraction: 0.75) on expandedID state drives frame height 140->280"
  - "openDirections is @MainActor to satisfy Swift 6 strict concurrency (UIApplication.shared is main actor isolated)"
  - "CarouselView registered in project.pbxproj: PBXFileReference AA000113, PBXBuildFile AA000017"
  - "isUserScrolling guard prevents onChange(of: scrollID) firing when programmatic scroll sets scrollID"
  - "Load-more trigger: onAppear fires when place is among last 3 items in places array"
  - "Initial selectedPlace set after fetchNearby completes in both .task and onChange(of: location)"

patterns-established:
  - "sensoryFeedback on compass needle Image (not on containing view) avoids triggering on scroll"
  - ".ignoresSafeArea(edges: .bottom) on ZStack so carousel extends to screen edge"
  - "CardView as private struct in same file as CarouselView — scoped to carousel context"
  - "StateCard and LoadingSkeleton as private structs — reusable but internal to CarouselView.swift"

# Metrics
duration: 3min
completed: 2026-02-22
---

# Phase 2 Plan 2: Carousel UI Summary

**Snap-to-card pizza place carousel overlaying the compass with expand-for-details, walking directions handoff (Google Maps/Apple Maps), live distance updates, and complete error state handling**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-22T01:09:58Z
- **Completed:** 2026-02-22T01:13:35Z (before checkpoint)
- **Tasks:** 2 autonomous + 1 checkpoint (human-verify)
- **Files modified:** 5

## Accomplishments

- Created CarouselView.swift — horizontal snap-to-card ScrollView using `.scrollTargetBehavior(.viewAligned)` and `.scrollPosition(id:)`. GeometryReader computes card width with 40pt peek on each side. LazyHStack renders `ForEach(placesService.places)` with `.scrollTargetLayout()`. scrollID onChange sets `appState.selectedPlace` and collapses expanded cards.
- CardView shows place name and pizza-slice distance collapsed; expands in place to show address, phone, website Link, and "Get Directions" button. Directions button shows `confirmationDialog` on first use to choose Google Maps or Apple Maps (stored via `@AppStorage`). Deep link opens `comgooglemaps://` (walking mode) or `maps.apple.com` fallback.
- Rendered offline (wifi.slash), noResults (takeoutbag icon), searchFailed (exclamationmark.triangle), and loading skeleton states for all PlacesService conditions.
- Rewrote CompassView as ZStack — compass content (calibration or needle) fills screen, CarouselView overlays at bottom with `.padding(.bottom, 16)`. Added `.sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7), trigger: appState.isAligned)` on needle Image. Removed PlacePickerRow completely.
- Wired ContentView: `onChange(of: locationService.location)` triggers initial `fetchNearby` on first fix (places empty), then `updateDistances` on subsequent 50m moves. `.task` on CompassView for when location already available at view appearance. Sets `appState.selectedPlace` to nearest place after fetch.
- TakeMeToPizzaApp: NetworkMonitor allocated via `State(initialValue: NetworkMonitor())` and injected via `.environment(networkMonitor)` after existing environment calls.

## Task Commits

Each task was committed atomically:

1. **Task 1: CarouselView with CardView, directions handoff, and maps preference** - `92287f7` (feat)
2. **Task 2: Wire carousel into CompassView, ContentView fetching, TakeMeToPizzaApp injection** - `d2294b7` (feat)

**Status:** Awaiting human-verify checkpoint before SUMMARY commit.

## Files Created/Modified

- `TakeMeToPizza/Views/CarouselView.swift` — Created. 280 lines. Snap-to-card carousel with all card logic, state rendering, and directions handoff.
- `TakeMeToPizza/Views/CompassView.swift` — Rewritten. ZStack layout with CarouselView overlay, haptic sensoryFeedback, PlacePickerRow removed.
- `TakeMeToPizza/ContentView.swift` — fetchNearby and updateDistances wired to locationService.location changes. PlacesService environment dependency added.
- `TakeMeToPizza/TakeMeToPizzaApp.swift` — NetworkMonitor state added, allocated in init(), injected via .environment().
- `TakeMeToPizza.xcodeproj/project.pbxproj` — CarouselView.swift registered in PBXBuildFile, PBXFileReference, Views group, Sources build phase.

## Decisions Made

- **openDirections is @MainActor:** Swift 6 strict concurrency requires `@MainActor` annotation on functions accessing `UIApplication.shared`. Added to free function in CarouselView.swift.
- **Expand animation drives frame height on GeometryReader:** The outer GeometryReader wraps everything; `expandedID != nil` switches height from 140 to 280 with spring animation. This expands the carousel strip in place upward.
- **isUserScrolling guard:** Prevents `onChange(of: scrollID)` from firing when a programmatic scroll (future extension) sets scrollID, which would create feedback loops.
- **CardView private struct in same file:** Scoped to carousel context; no need for external access. Follows existing CompassView pattern for PlacePickerRow.
- **Initial selectedPlace in both .task and onChange:** Both paths (pre-authorized location and location-fix-after-launch) set selectedPlace post-fetch to ensure compass targets the nearest place immediately.

## Deviations from Plan

None - plan executed exactly as written. `openDirections` was annotated `@MainActor` to satisfy Swift 6 strict concurrency (Rule 2 - missing critical for build correctness), which is consistent with what the plan intended.

## Issues Encountered

None. Build succeeded on first attempt.

## User Setup Required

None - no new configuration required. Google Maps scheme already declared in Info.plist from Plan 02-01.

## Next Phase Readiness

- Checkpoint required: human-verify on physical device to confirm real places appear in carousel, snap behavior works, compass reorients on card change, and directions open correctly
- Phase 3 (design and personality): CarouselView/CardView ready for neobrutalist restyle. ZStack structure in CompassView ready for custom pizza-slice compass needle replacement.
- Concern: MKLocalSearch result quality still unverified — physical device test in checkpoint will surface this

---
*Phase: 02-places-and-discovery*
*Completed: 2026-02-22*
