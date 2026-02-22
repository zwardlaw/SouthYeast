# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-21)

**Core value:** The pizza slice compass always points to the nearest pizza. Open the app, find pizza.
**Current focus:** Phase 3 — Design and Personality (Plan 1 of 2 complete)

**App name:** Take Me to Pizza (rebranded from SouthYeast on 2026-02-21)

## Current Position

Phase: 3 of 3 (Design and Personality) — In Progress
Plan: 1 of 2 in current phase — COMPLETE
Status: In progress — ready for Plan 02 (full app restyling)
Last activity: 2026-02-22 — Completed 03-01-PLAN.md

Progress: [███████░░░] 75%

## Performance Metrics

**Velocity:**
- Total plans completed: 6
- Average duration: 6.2 min
- Total execution time: 43 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-compass-core | 3/3 (COMPLETE) | 18 min | 6 min |
| 02-places-and-discovery | 2/2 (COMPLETE) | 8 min | 4 min |
| 03-design-and-personality | 1/2 (in progress) | 17 min | 17 min |

**Recent Trend:**
- Last 6 plans: 4 min, 6 min, 8 min, 4 min, 4 min, 17 min
- Trend: 03-01 took longer (design system + font downloads + pbxproj conflict resolution)

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: Zero third-party dependencies — use Apple native stack (Swift 6, SwiftUI, Core Location, MapKit)
- [Roadmap]: MKLocalSearch as primary places backend; Google Places SDK v10.8.0 as escalation path only
- [Roadmap]: Compass mechanics correctness validated in Phase 1 before any UI polish work begins
- [01-01]: Bundle identifier: com.takemetopizza.app (rebranded from com.southyeast.app)
- [01-01]: project.pbxproj hand-authored (swift package init not viable for SwiftUI app targets)
- [01-01]: PrivacyInfo.xcprivacy included in project.pbxproj Resources build phase at creation time
- [01-02]: PermissionStatus enum defined in LocationService.swift — keeps related domain types together
- [01-02]: CLHeading scalar extraction before Task boundary enforced — CLHeading is not Sendable in Swift 6
- [01-02]: headingAccuracy defaults to -1.0 so app always starts in calibration state on launch and resume
- [01-02]: MKLocalSearch deferred to Phase 2 (INFR-06) — PlacesService stub serves Phase 1 compass validation needs
- [01-03]: Accumulated angle delta — compassAngle accumulates shortest-arc deltas, never raw 0-360 values
- [01-03]: Info.plist requires CFBundle* keys when GENERATE_INFOPLIST_FILE=NO — CFBundleIdentifier must be explicit
- [01-03]: Single-allocation @State pattern — declare without default, init via State(initialValue:) in App.init()
- [01-03]: TakeMeToPizzaTests BUNDLE_LOADER + TEST_HOST point to app binary for @testable import
- [02-01]: Pizza slice distance unit: 1 slice = 8 inches = 0.2032 meters (distanceInPizzaSlices computed property)
- [02-01]: MKCoordinateRegion uses latitudinalMeters*2/longitudinalMeters*2 for radius — square bounding box slightly larger than circle
- [02-01]: isAligned uses previousRawAngle normalized to 0-360 (not accumulated compassAngle) for stability
- [02-01]: wasAligned flag tracks false->true edge for lastAlignmentTime update (prevents repeated haptic triggers)
- [02-01]: NetworkMonitor pbxproj IDs: PBXFileReference AA000112, PBXBuildFile AA000016
- [02-02]: CarouselView pbxproj IDs: PBXFileReference AA000113, PBXBuildFile AA000017
- [02-02]: openDirections is @MainActor (Swift 6 strict concurrency — UIApplication.shared is main actor isolated)
- [02-02]: cardWidth = proxy.size.width - 80 (40pt peek each side via GeometryReader)
- [02-02]: ZStack(alignment: .bottom) in CompassView — compass fills screen, CarouselView overlays at bottom
- [03-01]: PBXBuildFile IDs AA000026/027 for PizzaSliceNeedle/MotionService (AA000022/023 collided with existing build phase objects)
- [03-01]: Font PBXFileReference IDs AA000122/123 (AA000120 already used for TakeMeToPizzaTests.xctest)
- [03-01]: Space Grotesk downloaded as static 400-weight TTF — variable font not available as TTF from public CDN
- [03-01]: MotionService view-scoped in CompassView, not app-level environment — battery-safe
- [03-01]: PizzaSliceNeedle uses clockwise: false in addArc — SwiftUI's flipped Y coord system inverts visual direction

### Pending Todos

None.

### Blockers/Concerns

- [Phase 1 verify]: Simulator shows calibration state (no real magnetometer). Test on physical device to verify live compass rotation.
- [Phase 2 risk]: MKLocalSearch result quality is unverified in target markets. Test on real device in target city early in Phase 2. If quality is insufficient, Google Places escalation path is fully researched (SDK v10.8.0, SPM).
- [03-01 font]: Space Grotesk at 400 weight only (static TTF). If design requires bold/medium weights, need to download additional weights or find variable TTF source.
- [03-01 tilt]: Device tilt parallax is static on Simulator (CMMotionManager unavailable). Must test on physical device for tilt effect.

## Session Continuity

Last session: 2026-02-22
Stopped at: 03-01-PLAN.md complete
Resume file: None
