---
phase: 01-compass-core
plan: 02
subsystem: infra
tags: [swift6, corelocation, clLocationManager, observable, heading, compass, places]

# Dependency graph
requires:
  - phase: 01-01
    provides: Xcode project scaffold with Services/, Models/ group structure and Swift 6 strict concurrency settings
provides:
  - LocationService: @Observable @MainActor CLLocationManager wrapper with full permission state machine
  - PermissionStatus enum mapping all CLAuthorizationStatus values to app domain type
  - PlacesService: @Observable @MainActor stub with 3 hardcoded NYC pizza places for Phase 1 testing
  - Place: Identifiable, Equatable value type with id, name, coordinate
affects: [01-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@Observable @MainActor final class for services shared across SwiftUI views"
    - "nonisolated CLLocationManagerDelegate methods with scalar extraction before Task { @MainActor in } boundary"
    - "CLHeading scalar extraction pattern: extract trueHeading and headingAccuracy as Doubles before Task boundary"
    - "headingAccuracy = -1.0 sentinel for calibration state gating"

key-files:
  created:
    - SouthYeast/Models/Place.swift
    - SouthYeast/Services/PlacesService.swift
    - SouthYeast/Services/LocationService.swift
  modified:
    - SouthYeast.xcodeproj/project.pbxproj

key-decisions:
  - "PermissionStatus enum defined in LocationService.swift (not a separate file) — keeps related domain types together"
  - "CLHeading scalar extraction before Task boundary enforced — CLHeading is not Sendable in Swift 6"
  - "headingAccuracy defaults to -1.0 so app always starts in calibration state pending first valid reading"
  - "stopUpdating() resets headingAccuracy to -1.0 so calibration overlay shows correctly on resume"
  - "MKLocalSearch deferred to Phase 2 (INFR-06) — PlacesService stub serves Phase 1 compass validation needs"

patterns-established:
  - "All CLLocationManagerDelegate methods are nonisolated — required for Swift 6 strict concurrency"
  - "CLLocation is Sendable (capture directly); CLHeading is not Sendable (extract scalars first)"
  - "heading update gating: if accuracy >= 0 { self.heading = trueHeading } — never update on invalid readings"

# Metrics
duration: 6min
completed: 2026-02-21
---

# Phase 1 Plan 02: Services — LocationService and PlacesService Summary

**@Observable CLLocationManager wrapper with nonisolated delegate pattern, headingAccuracy gating, and PlacesService stub with 3 NYC pizza places for compass bearing validation**

## Performance

- **Duration:** 6 min
- **Started:** 2026-02-21T22:10:15Z
- **Completed:** 2026-02-21T22:16:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- LocationService: full CLLocationManager wrapper compiling under Swift 6 strict concurrency with 5 nonisolated delegate methods
- Permission state machine mapping all CLAuthorizationStatus values to PermissionStatus enum (.notDetermined, .denied, .restricted, .authorized)
- Heading accuracy gating enforced — trueHeading only written to observable state when accuracy >= 0
- stopUpdating() resets headingAccuracy to -1.0 so calibration overlay appears correctly on resume
- PlacesService: 3 hardcoded NYC pizza places (Joe's Pizza, Di Fara, Lucali) with spread bearings across Manhattan/Brooklyn for compass validation

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Place model and PlacesService stub** - `5e870f4` (feat)
2. **Task 2: Create LocationService with permission state machine** - `d237b6e` (feat)

**Plan metadata:** (docs: complete plan — committed below)

## Files Created/Modified
- `SouthYeast/Models/Place.swift` - Identifiable, Equatable value type with id, name, CLLocationCoordinate2D
- `SouthYeast/Services/PlacesService.swift` - @Observable @MainActor stub with 3 hardcoded NYC pizza places
- `SouthYeast/Services/LocationService.swift` - @Observable @MainActor CLLocationManager wrapper; PermissionStatus enum; startUpdating/stopUpdating; 5 nonisolated delegate methods
- `SouthYeast.xcodeproj/project.pbxproj` - PBXFileReference, PBXBuildFile, Sources build phase, and group entries for all 3 new files

## Decisions Made
- PermissionStatus enum defined in LocationService.swift alongside the service that uses it — keeps related types together without a separate file
- CLHeading scalar extraction enforced before Task boundary: `let trueHeading = newHeading.trueHeading` extracted in nonisolated context, then passed into `Task { @MainActor in }`. CLHeading is not Sendable in Swift 6.
- headingAccuracy defaults to -1.0 at init time so app always begins in calibration-needed state — no stale readings on first launch
- MKLocalSearch deferred to Phase 2 per plan — PlacesService stub is sufficient for compass math and rotation validation in Phase 1

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- LocationService and PlacesService are ready for 01-03 (CompassMath + CompassView)
- 01-03 can inject LocationService and PlacesService and immediately access heading, location, authorizationStatus, permissionStatus, and places[]
- No blockers for 01-03 execution

---
*Phase: 01-compass-core*
*Completed: 2026-02-21*
