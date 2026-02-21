---
phase: 01-compass-core
plan: 03
subsystem: ui
tags: [swiftui, coreLocation, bearing-math, compass, animation, unit-tests, xctest]

# Dependency graph
requires:
  - phase: 01-01
    provides: Xcode project scaffold, Swift 6 + iOS 17 build settings, folder structure
  - phase: 01-02
    provides: LocationService (@Observable CLLocationManager, PermissionStatus enum, headingAccuracy), PlacesService stub (3 NYC places), Place model

provides:
  - BearingMath.swift: pure bearing() and normalizeAngleDelta() functions with 5 passing unit tests
  - AppState.swift: accumulated compassAngle (delta-based, not raw), isCalibrating, selectedPlace
  - CompassView.swift: spring-animated arrow needle, calibration overlay, PlacePickerRow for COMP-05 verification
  - ContentView.swift: permission routing (4 states), scenePhase lifecycle, onChange heading/selectedPlace wiring
  - TakeMeToPizzaApp.swift: single-allocation @State pattern, .environment() injection for all 3 services
  - TakeMeToPizzaTests target: test scheme, BearingMathTests (5/5 pass)

affects:
  - 02-places-carousel: CompassView PlacePickerRow is replaced by the carousel; AppState.selectedPlace binding is unchanged
  - 03-polish: CompassView needle (location.north.fill) replaced by custom pizza slice Shape

# Tech tracking
tech-stack:
  added: [XCTest (TakeMeToPizzaTests target), interpolatingSpring animation]
  patterns:
    - Accumulated angle delta rotation (prevents 0/360 boundary spin)
    - Single-allocation @State pattern via State(initialValue:) in App.init()
    - Environment-injected @Observable services at App root, read via @Environment in Views
    - Permission-gated routing in ContentView switch on locationService.permissionStatus

key-files:
  created:
    - TakeMeToPizza/Math/BearingMath.swift
    - TakeMeToPizza/Models/AppState.swift
    - TakeMeToPizza/Views/CompassView.swift
    - TakeMeToPizzaTests/BearingMathTests.swift
  modified:
    - TakeMeToPizza/ContentView.swift
    - TakeMeToPizza/TakeMeToPizzaApp.swift
    - TakeMeToPizza/Info.plist
    - TakeMeToPizza.xcodeproj/project.pbxproj
    - TakeMeToPizza.xcodeproj/xcshareddata/xcschemes/TakeMeToPizza.xcscheme

key-decisions:
  - "Accumulated angle delta: compassAngle never clamped to 0-360; accumulates shortest-arc deltas to prevent full-circle spin at north boundary"
  - "Single-allocation @State: declare without default, init only via State(initialValue:) in App.init() to avoid double-allocation discard"
  - "Info.plist required CFBundle* keys: GENERATE_INFOPLIST_FILE=NO requires explicit CFBundleIdentifier or tests cannot install on simulator"
  - "TakeMeToPizzaTests target: BUNDLE_LOADER + TEST_HOST point to TakeMeToPizza.app so @testable import works correctly"

patterns-established:
  - "Accumulated rotation: rawAngle = bearing - heading; delta = normalizeAngleDelta(rawAngle - previousRawAngle); compassAngle += delta"
  - "Environment injection: all @Observable services injected at WindowGroup root via .environment(); read with @Environment(Type.self)"
  - "Lifecycle: scenePhase.active -> startUpdating, scenePhase.background -> stopUpdating (headingAccuracy resets to -1.0)"

# Metrics
duration: 8min
completed: 2026-02-21
---

# Phase 1 Plan 3: Compass Math + Views Summary

**bearing-minus-heading accumulated rotation with interpolatingSpring animation, 5/5 unit tests for N/S/E/W cardinal directions and shortest-arc normalization**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-21T22:16:01Z
- **Completed:** 2026-02-21T22:24:09Z
- **Tasks:** 2 auto tasks complete (checkpoint pending human verification)
- **Files modified:** 8

## Accomplishments

- BearingMath pure functions with 5 passing XCTest unit tests (cardinal N/S/E/W + 0/360 wrap)
- AppState accumulated rotation with shortest-arc delta — prevents full-circle spin at north boundary
- CompassView with interpolatingSpring(stiffness:170, damping:26) animation and calibration state overlay
- ContentView permission routing (4 states) + scenePhase lifecycle (active/background)
- TakeMeToPizzaApp single-allocation pattern — no double-init discard of @Observable services
- Place picker row validates COMP-05 re-targeting at runtime

## Task Commits

Each task was committed atomically:

1. **Task 1: BearingMath with unit tests, AppState with accumulated rotation** - `5d2116f` (feat)
2. **Task 2: CompassView with place picker, ContentView routing, TakeMeToPizzaApp wiring, lifecycle** - `77a4564` (feat)

## Files Created/Modified

- `TakeMeToPizza/Math/BearingMath.swift` - Pure bearing(from:to:) and normalizeAngleDelta(_:) functions
- `TakeMeToPizza/Models/AppState.swift` - Accumulated compassAngle, isCalibrating, updateCompassAngle()
- `TakeMeToPizza/Views/CompassView.swift` - Spring-animated needle, calibration overlay, PlacePickerRow
- `TakeMeToPizzaTests/BearingMathTests.swift` - 5 XCTest unit tests (all passing)
- `TakeMeToPizza/ContentView.swift` - Permission routing + scenePhase lifecycle + onChange wiring
- `TakeMeToPizza/TakeMeToPizzaApp.swift` - Single-allocation @State pattern, .environment() injection
- `TakeMeToPizza/Info.plist` - Added required CFBundle* keys (CFBundleIdentifier was missing)
- `TakeMeToPizza.xcodeproj/project.pbxproj` - TakeMeToPizzaTests target, new file registrations
- `TakeMeToPizza.xcodeproj/xcshareddata/xcschemes/TakeMeToPizza.xcscheme` - Added test target to scheme

## Decisions Made

- **Accumulated angle delta**: `compassAngle` accumulates shortest-arc deltas, never set to raw 0-360 values. This is the correct pattern — without it, the needle spins a full circle whenever heading crosses north.
- **Info.plist CFBundle* keys**: `GENERATE_INFOPLIST_FILE = NO` requires explicit `CFBundleIdentifier = $(PRODUCT_BUNDLE_IDENTIFIER)` and related keys in the Info.plist. Without them, the app built but tests failed to install on simulator ("Missing bundle ID").
- **TakeMeToPizzaTests bundle loader**: Test target configured with `BUNDLE_LOADER = "$(TEST_HOST)"` and `TEST_HOST` pointing to the app binary so `@testable import TakeMeToPizza` works.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Info.plist missing required CFBundle* keys**
- **Found during:** Task 1 (running unit tests)
- **Issue:** Info.plist only contained usage strings and UIApplicationSceneManifest. With `GENERATE_INFOPLIST_FILE = NO`, Xcode uses this file directly — no CFBundleIdentifier meant the app installed without a bundle ID and tests failed: "Missing bundle ID."
- **Fix:** Added `CFBundleIdentifier = $(PRODUCT_BUNDLE_IDENTIFIER)`, `CFBundleExecutable`, `CFBundleName`, `CFBundlePackageType`, `CFBundleShortVersionString`, `CFBundleVersion` to Info.plist using build-settings variable substitution
- **Files modified:** `TakeMeToPizza/Info.plist`
- **Verification:** Tests install and run successfully; Executed 5 tests, with 0 failures
- **Committed in:** `5d2116f` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Required for tests to run. No scope creep.

## Issues Encountered

- Simulator device specifier `platform=iOS Simulator,name=iPhone 16` failed (device not registered); switched to `id=78656FDE-CC68-4C65-B606-F4F0C277CE42` (iPhone 16 Pro by UDID). Tests ran successfully.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Compass math is validated by 5 unit tests — bearing math is correct
- Accumulated rotation pattern is implemented — no full-circle spins at north boundary
- CompassView renders calibration state or animated needle based on AppState
- ContentView routes on all 4 permission states
- App compiles under Swift 6 strict concurrency with zero errors
- Ready for Phase 2: places carousel, MKLocalSearch integration (INFR-06)
- Concern: Simulator shows calibration state (no real magnetometer) — test on physical device to verify live compass rotation

---
*Phase: 01-compass-core*
*Completed: 2026-02-21*
