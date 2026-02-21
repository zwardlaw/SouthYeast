# Phase 1: Compass Core - Research

**Researched:** 2026-02-21
**Domain:** Swift 6 / SwiftUI project scaffold, Core Location permission state machine, CLLocationManager heading, bearing math, compass rotation animation
**Confidence:** HIGH (primary sources: Apple Developer Documentation, verified Swift forums, official Swift concurrency docs)

---

## Summary

Phase 1 builds the technical foundation the entire app depends on: a Swift 6 SwiftUI project, a `@Observable` `LocationService` wrapping `CLLocationManager`, a full permission state machine, and a `CompassView` with mathematically correct rotation. The project research (STACK.md, ARCHITECTURE.md, PITFALLS.md) already covers the domain thoroughly. This document focuses on the Phase 1-specific implementation questions that the planner needs to make concrete task decisions.

The three most critical correctness issues — the 0/360 wrap causing full-circle animation, missing `bearing - deviceHeading` subtraction, and `magneticHeading` vs `trueHeading` mismatch — must all be addressed in Phase 1. These are invisible during development (when the developer faces one direction in a quiet indoor space) and are catastrophic in user testing outdoors. They cannot be deferred.

Swift 6 strict concurrency introduces a specific gotcha with `CLLocationManager` delegates: delegate methods fire on the thread where the manager was initialized, but Swift's compiler cannot verify this statically. The solution is `nonisolated` on delegate methods + `Task { @MainActor in ... }` to bridge back. This is the established community pattern and is not complex once understood.

**Primary recommendation:** Build `LocationService` as `@Observable @MainActor final class` with `nonisolated` delegate methods that use `Task { @MainActor in ... }` to update properties. Track compass rotation as an accumulated angle (apply deltas, never set absolute 0-360 values) to solve the wrap problem. Use `trueHeading` exclusively; never `magneticHeading`.

---

## Standard Stack

### Core (all Apple-native, zero third-party dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift | 6.x (Xcode 16+) | Language | Required for strict concurrency checking, @Observable, modern async/await |
| SwiftUI | iOS 17 minimum | All UI | @Observable, `.onChange(of:)` two-arg form, `scenePhase` |
| Core Location | iOS 17 API | Heading + GPS | `CLLocationManager`, `CLHeading`, `CLLocationUpdate.liveUpdates()` |
| Observation framework | iOS 17 | `@Observable` macro | Selective re-rendering; critical for 10-20 Hz heading updates |
| Foundation | Built-in | Math utilities, `CLLocationCoordinate2D` | Bearing calculation uses standard trig |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| MapKit | iOS 17+ | `MKLocalSearch` for Phase 1 stub places data | Phase 1 uses a hardcoded place to verify compass mechanics; Phase 2 wires real search |
| XCTest | Built-in | Unit test bearing math and angle normalization | Bearing formula must be unit tested before any animation work |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `@Observable` | `ObservableObject + @Published` | ObservableObject triggers all observing views on any @Published change; heading at 20 Hz causes render thrashing. Do not use. |
| Delegate pattern for heading | `CLLocationUpdate.liveUpdates()` AsyncSequence | `liveUpdates()` covers GPS position but heading still requires `startUpdatingHeading()` + delegate. Heading has no async alternative as of iOS 17. |
| Native `scenePhase` | `UIApplicationDelegate` lifecycle | `scenePhase` is sufficient for iOS foreground/background detection. Jesse Squires (2024) notes it has macOS issues, but iOS behavior is reliable. |

**Installation:** No packages to install. All frameworks are native. Configure via Xcode target settings.

---

## Architecture Patterns

### Recommended Project Structure

```
SouthYeast/
├── SouthYeastApp.swift        # @main, bootstraps services, .environment() injection
├── ContentView.swift          # Root view; switches on permissionStatus
├── Services/
│   ├── LocationService.swift  # @Observable @MainActor CLLocationManager wrapper
│   └── PlacesService.swift    # @Observable MKLocalSearch wrapper (stub in Phase 1)
├── Models/
│   ├── AppState.swift         # @Observable compassAngle, selectedPlace, permissionStatus
│   └── Place.swift            # Value type wrapping MKMapItem
├── Views/
│   └── CompassView.swift      # rotationEffect + interpolatingSpring animation
├── Math/
│   └── BearingMath.swift      # Pure functions: bearing(from:to:), normalizeAngleDelta()
└── Resources/
    ├── PrivacyInfo.xcprivacy  # Required from day 1 (App Store compliance)
    └── Assets.xcassets        # App icon, accent color placeholders
```

### Pattern 1: @Observable @MainActor LocationService with nonisolated Delegates

**What:** A single `@Observable @MainActor final class` that wraps one `CLLocationManager`. Delegate methods are `nonisolated` and bridge to main actor via `Task`.

**When to use:** Always. This is the only correct pattern for `CLLocationManager` with Swift 6 strict concurrency.

**Why:** Core Location documentation states delegates fire on "the RunLoop of the thread on which you initialized the CLLocationManager object." In practice with `@MainActor`, the manager is created on the main thread, so delegates fire on the main thread — but Swift's concurrency checker cannot verify this statically. Marking delegates `nonisolated` satisfies the compiler; the `Task { @MainActor in ... }` bridge is cheap (the work actually runs on main anyway).

```swift
// Source: Apple Developer Forums thread/711646 + community Swift 6 concurrency patterns
@Observable
@MainActor
final class LocationService: NSObject {
    // Published state (main-actor isolated)
    var location: CLLocation?
    var heading: Double = 0.0              // trueHeading, degrees
    var headingAccuracy: Double = -1.0     // negative = invalid
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 50        // only fire on 50m movement
        manager.headingFilter = 1.0        // only fire on 1+ degree change
    }

    func startUpdating() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()     // requires location updates to be running for trueHeading
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }
}

extension LocationService: CLLocationManagerDelegate {
    // CRITICAL: Mark nonisolated to satisfy Swift 6 concurrency checker
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.location = loc
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Extract values before crossing actor boundary (CLHeading is not Sendable)
        let trueH = newHeading.trueHeading
        let accuracy = newHeading.headingAccuracy
        Task { @MainActor in
            self.headingAccuracy = accuracy
            if accuracy >= 0 {
                self.heading = trueH
            }
            // if accuracy < 0: invalid — do not update heading; keep previous value
        }
    }

    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return true  // Let iOS show the figure-eight calibration prompt
    }
}
```

**Important:** `CLHeading` is not `Sendable`. Extract scalar values (`Double`) from `CLHeading` in the `nonisolated` context before the `Task { @MainActor in ... }` crossing. Do not capture `CLHeading` itself across actor boundaries.

### Pattern 2: Permission State Machine

**What:** `LocationService` drives a `PermissionStatus` enum that gates all compass and places functionality.

**When to use:** From the first line of location code. All compass and search code only runs from `.authorized` state onward.

```swift
// Source: PITFALLS.md (project research) + Apple CLAuthorizationStatus docs
enum PermissionStatus: Equatable {
    case notDetermined      // First launch, no prompt yet
    case denied             // User tapped "Don't Allow" — permanent until Settings
    case restricted         // Parental controls — user cannot change
    case authorized         // .authorizedWhenInUse — nominal path
}

// In LocationService:
var permissionStatus: PermissionStatus {
    switch authorizationStatus {
    case .notDetermined: return .notDetermined
    case .denied: return .denied
    case .restricted: return .restricted
    case .authorizedWhenInUse, .authorizedAlways: return .authorized
    @unknown default: return .notDetermined
    }
}
```

**ContentView routing by permission state:**

```swift
// Root view switches on permission status — no compass shown until authorized
var body: some View {
    switch locationService.permissionStatus {
    case .notDetermined:
        PermissionPrimingView()            // Custom pre-prompt screen
    case .denied:
        PermissionDeniedView()             // Deep-link to Settings
    case .restricted:
        PermissionRestrictedView()         // "Ask a parent" message
    case .authorized:
        CompassView()                      // Main experience
    }
}
```

### Pattern 3: Compass Bearing Math

**What:** Pure functions for geodetic bearing calculation and angle normalization. Lives in `BearingMath.swift`. No dependency on services.

**When to use:** `AppState.compassAngle` calls these. Pure functions are unit-testable in isolation.

```swift
// Source: Movable Type Scripts (established spherical trig), project ARCHITECTURE.md
// Verified: matches Apple Developer Forums thread/108865 bearing calculation

extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}

/// Returns bearing in degrees (0-360) from geographic north
func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let lat1 = from.latitude.degreesToRadians
    let lat2 = to.latitude.degreesToRadians
    let dLon = (to.longitude - from.longitude).degreesToRadians
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let bearing = atan2(y, x).radiansToDegrees
    return (bearing + 360).truncatingRemainder(dividingBy: 360)
}

/// Normalizes an angle delta to [-180, 180] for shortest-arc animation
/// Source: ARCHITECTURE.md pattern 6, community compass implementations
func normalizeAngleDelta(_ delta: Double) -> Double {
    var d = delta.truncatingRemainder(dividingBy: 360)
    if d > 180  { d -= 360 }
    if d < -180 { d += 360 }
    return d
}
```

### Pattern 4: Accumulated Rotation (Solving the 0/360 Wrap)

**What:** Track compass angle as a monotonically-accumulating `Double`, not a clamped 0-360 value. Apply deltas from each heading update rather than setting an absolute angle.

**When to use:** Every time the heading or target changes. This is the only correct approach for SwiftUI `rotationEffect` animation without full-circle spins.

**Why:** SwiftUI's `.interpolatingSpring` interpolates `Double` values linearly. Going from angle 359 to angle 1 produces a 358-degree backward spin instead of a 2-degree forward rotation. Accumulated rotation avoids this: going from accumulated angle 359 to accumulated angle 361 (= 1 degree in absolute terms) correctly produces a 2-degree forward swing.

```swift
// Source: PITFALLS.md Pitfall 1, community compass patterns
// In AppState:
@Observable
@MainActor
final class AppState {
    var selectedPlace: Place?

    // Accumulated rotation — never clamped to 0-360
    private(set) var compassAngle: Double = 0.0
    private var previousCompassAngle: Double = 0.0

    private let locationService: LocationService

    /// Call this whenever heading or selectedPlace changes
    func updateCompassAngle() {
        guard let place = selectedPlace,
              let location = locationService.location,
              locationService.headingAccuracy >= 0 else {
            // Invalid heading: do not update (show calibration state in view)
            return
        }
        let bear = bearing(from: location.coordinate, to: place.coordinate)
        let rawAngle = bear - locationService.heading
        let delta = normalizeAngleDelta(rawAngle - previousCompassAngle)
        compassAngle += delta
        previousCompassAngle = rawAngle
    }

    var isCalibrating: Bool {
        locationService.headingAccuracy < 0
    }
}
```

### Pattern 5: CompassView with Spring Animation

**What:** `CompassView` reads `AppState.compassAngle` and applies `rotationEffect` with `interpolatingSpring`. Shows a calibration state when `isCalibrating` is true.

```swift
// Source: STACK.md, Apple SwiftUI documentation
struct CompassView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isCalibrating {
                CalibrationStateView()    // "Move phone in figure-eight"
            } else {
                PizzaSliceShape()         // Or Image("pizza-slice") in Phase 1
                    .rotationEffect(.degrees(appState.compassAngle))
                    .animation(
                        .interpolatingSpring(stiffness: 170, damping: 26),
                        value: appState.compassAngle
                    )
            }
        }
    }
}
```

**Note:** `PizzaSliceShape` is a placeholder in Phase 1 — a circle or arrow is fine. Phase 3 adds the custom pizza slice `Shape`. What matters in Phase 1 is the rotation correctness, not the visual.

### Pattern 6: App Lifecycle with scenePhase

**What:** On foreground restore, show calibration state until the first new heading callback arrives. Do not display stale heading from before backgrounding.

```swift
// Source: Apple SwiftUI scenePhase docs, PITFALLS.md Pitfall 12
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(LocationService.self) private var locationService

    var body: some View {
        // ... main content ...
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // heading updates resume automatically after foreground restore;
                // calibration state is shown until first valid CLHeading callback fires
                locationService.startUpdating()
            case .background:
                locationService.stopUpdating()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
```

**Key insight:** Heading callbacks do NOT resume immediately on foreground — there is a brief delay (< 1 second in practice). By having `headingAccuracy` start at -1 and only updating it when valid headings arrive, `CompassView` automatically shows `CalibrationStateView` during the gap.

### Pattern 7: Service Injection at App Entry

```swift
// Source: ARCHITECTURE.md Pattern 1
@main
struct SouthYeastApp: App {
    @State private var locationService = LocationService()
    @State private var placesService = PlacesService()
    @State private var appState: AppState

    init() {
        let loc = LocationService()
        let places = PlacesService()
        let state = AppState(locationService: loc, placesService: places)
        _locationService = State(initialValue: loc)
        _placesService = State(initialValue: places)
        _appState = State(initialValue: state)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationService)
                .environment(placesService)
                .environment(appState)
        }
    }
}
```

**Note on `@State` vs `@StateObject`:** With `@Observable`, use `@State` to hold service instances in the `App` struct — not `@StateObject` (which is for `ObservableObject`). `@State` in `App` persists for the app's lifetime.

### Anti-Patterns to Avoid

- **`magneticHeading` instead of `trueHeading`:** Systematic error of 10-20 degrees depending on city. `trueHeading` requires `startUpdatingLocation()` to be running simultaneously.
- **`CLLocationManager` created in a view:** Multiple managers produce duplicate permission prompts and duplicate delegate callbacks.
- **Raw 0-360 angle passed to `rotationEffect`:** Causes full-circle spin when crossing north. Always use accumulated delta rotation.
- **`ObservableObject + @Published` for LocationService:** Any property change triggers all observers. Heading at 20 Hz re-renders the entire view tree.
- **Checking `heading` without checking `headingAccuracy`:** Invalid readings (accuracy < 0) produce garbage directions. Always gate on accuracy.
- **Calling `startUpdatingLocation()` before authorization is granted:** No-op and potentially confusing — call inside `locationManagerDidChangeAuthorization` when status becomes authorized.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Heading async wrapper | Custom `AsyncStream` wrapping CLLocationManager delegate | Native delegate + `@Observable` | Delegate pattern wraps cleanly into `@Observable`; `CLLocationUpdate.liveUpdates()` doesn't cover heading |
| Permission management library | PermissionsSwiftUI or VWWPermissionKit | Native `CLAuthorizationStatus` switch | Simple enum; four states; no library complexity justified |
| Rotation animation library | Lottie, RealityKit | SwiftUI `rotationEffect` + `interpolatingSpring` | Live data-driven rotation cannot use canned animation files |
| Location math | SwiftLocation (github.com/malcommac) | Native CLLocationManager | iOS 17 provides this natively; adding a library adds maintenance risk |
| Compass bearing formula | Hand-derived from scratch | The `atan2(y, x)` formula in BearingMath.swift | This formula is established spherical trig; it's short and correct. The only risk is implementation bugs — hence unit tests. |

**Key insight:** In this domain, the risk is not "too hard to build" — it's "looks right in development, fails in user testing." The bearing formula is 4 lines. The danger is the `magneticHeading` vs `trueHeading` bug that makes it wrong by 15 degrees, or the 0/360 wrap that makes it spin incorrectly near north. Unit tests catch these; complexity doesn't cause them.

---

## Common Pitfalls

### Pitfall 1: The 0/360 Wrap — Compass Spins Full Circle Through North
**What goes wrong:** When bearing changes from 359 to 1 degrees, `withAnimation` interpolates through 358 degrees backward instead of 2 degrees forward.
**Why it happens:** SwiftUI animates raw `Double` values linearly. 359 and 1 are 358 apart numerically.
**How to avoid:** Use accumulated rotation (Pattern 4). Track `previousCompassAngle`; apply normalized delta each update. Never set `rotationEffect` to a raw 0-360 value.
**Warning signs:** Compass spins wildly when user faces north. Unit test: bearing 350 → 10 should animate +20, not -340.

### Pitfall 2: Missing `bearing - deviceHeading` Subtraction
**What goes wrong:** Compass points at a fixed map direction instead of rotating with the user. Turning the phone does not move the needle.
**Why it happens:** Bearing is a geographic direction (from true north). Device heading is what direction the phone faces. The on-screen rotation must be relative: `bearing - heading`.
**How to avoid:** In `AppState.updateCompassAngle()`: `rawAngle = bearing(to: place) - locationService.heading`.
**Warning signs:** Spinning the phone in place — slice should stay pointed at pizza. If slice rotates with the phone, heading is not being subtracted.

### Pitfall 3: `magneticHeading` vs `trueHeading` Mismatch
**What goes wrong:** Compass points 10-20 degrees off in a consistent direction (the local magnetic declination).
**Why it happens:** Bearing formula produces true north degrees. `magneticHeading` is relative to magnetic north. They differ by the local declination (e.g., ~15 degrees east in Seattle).
**How to avoid:** Always read `CLHeading.trueHeading`. It requires `startUpdatingLocation()` to also be running — if only heading updates are started, `trueHeading` returns -1. Check: if `trueHeading < 0`, fall back to `magneticHeading` and log a warning.
**Warning signs:** Consistent directional offset in one city. `CLHeading.trueHeading` logged as -1.

### Pitfall 4: `headingAccuracy < 0` Not Gated — Garbage Compass on Launch
**What goes wrong:** First launch indoors, magnetometer uncalibrated, `headingAccuracy` is -1. Compass confidently points at a random direction.
**Why it happens:** `magneticHeading` always has a value. Developers read it without checking `headingAccuracy`.
**How to avoid:** Gate all heading updates on `headingAccuracy >= 0`. Show `CalibrationStateView` when negative. Return `true` from `locationManagerShouldDisplayHeadingCalibration` to allow the iOS figure-eight prompt.
**Warning signs:** Compass shows a direction immediately on cold launch indoors.

### Pitfall 5: Swift 6 Concurrency Errors with CLLocationManagerDelegate
**What goes wrong:** Compiler error: "Capture of 'x' with non-sendable type 'CLLocationManager' in a @Sendable closure" or "Call to main actor-isolated instance method from nonisolated context."
**Why it happens:** `CLLocationManager` is not `Sendable`. `CLHeading` is not `Sendable`. Swift 6 strict concurrency checks these at compile time.
**How to avoid:** Mark all delegate methods `nonisolated`. Extract scalar values (`Double`, `CLAuthorizationStatus`) from non-Sendable types before the `Task { @MainActor in ... }` boundary. Do not capture `CLHeading` or `CLLocation` directly across actor boundaries — extract `.trueHeading`, `.headingAccuracy`, etc. as scalars first.
**Warning signs:** Compiler errors mentioning `@Sendable` or actor isolation in delegate methods.

### Pitfall 6: `PrivacyInfo.xcprivacy` Missing at Submission
**What goes wrong:** App Store rejection for missing or incomplete privacy manifest. Required since May 2024.
**Why it happens:** Not part of the default Xcode template; must be manually added.
**How to avoid:** Add `PrivacyInfo.xcprivacy` in plan step 01-01 (project scaffold). Declare: location data collected (coarse + precise), not linked to user identity, used for app functionality only. The `NSPrivacyAccessedAPITypes` section is for "required reason APIs" — these cover UserDefaults, file timestamps, disk space, system boot time. Core Location itself is declared in `NSPrivacyCollectedDataTypes` (as data collected), not in `NSPrivacyAccessedAPITypes`. Do not confuse the two sections.
**Warning signs:** No `PrivacyInfo.xcprivacy` file in the Xcode target's resources.

### Pitfall 7: Stale Heading Displayed After Backgrounding
**What goes wrong:** After returning from background, compass briefly shows the last pre-background direction instead of the current one. On fast phone rotations, this looks like a stuck compass.
**Why it happens:** `stopUpdatingHeading()` pauses heading callbacks. The first new callback after `startUpdatingHeading()` takes ~0.5-1.0 seconds.
**How to avoid:** On background, set `headingAccuracy = -1` to trigger calibration state. On foreground, call `startUpdating()` — the calibration state naturally masks the brief gap. (Pattern 6 above handles this.)
**Warning signs:** Compass shows wrong direction for 1-2 seconds after returning from background.

---

## Code Examples

### Complete LocationService (Phase 1 Scope)

```swift
// Source: Established Swift 6 pattern from Apple Developer Forums + community
import CoreLocation
import Observation

@Observable
@MainActor
final class LocationService: NSObject {
    var location: CLLocation?
    var heading: Double = 0.0
    var headingAccuracy: Double = -1.0     // Start invalid; gate compass on this
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    var permissionStatus: PermissionStatus {
        switch authorizationStatus {
        case .notDetermined:                           return .notDetermined
        case .denied:                                  return .denied
        case .restricted:                              return .restricted
        case .authorizedWhenInUse, .authorizedAlways:  return .authorized
        @unknown default:                              return .notDetermined
        }
    }

    private let manager: CLLocationManager

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 50.0     // meters
        manager.headingFilter = 1.0       // degrees
    }

    func startUpdating() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        case .denied, .restricted:
            break  // Cannot start; UI handles this state
        @unknown default:
            break
        }
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        headingAccuracy = -1.0  // Mark invalid so calibration state shows on resume
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            // Auto-start if permission just granted
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
                self.manager.startUpdatingHeading()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        // CLLocation IS Sendable as of iOS 14+ — safe to pass across actor boundary
        Task { @MainActor in
            self.location = loc
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateHeading newHeading: CLHeading) {
        // CLHeading is NOT Sendable — extract scalars before Task
        let trueH = newHeading.trueHeading
        let accuracy = newHeading.headingAccuracy
        Task { @MainActor in
            self.headingAccuracy = accuracy
            if accuracy >= 0 {
                self.heading = trueH
            }
        }
    }

    nonisolated func locationManagerShouldDisplayHeadingCalibration(
        _ manager: CLLocationManager
    ) -> Bool {
        return true
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        // Log error; location is optional so view handles nil gracefully
    }
}
```

### Bearing Math Unit Tests (BearingMath)

```swift
// These tests MUST pass before any animation work begins
// Source: Established spherical trig, verified against movable-type.co.uk formula

import XCTest
import CoreLocation

final class BearingMathTests: XCTestCase {
    func testBearingNorth() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let to   = CLLocationCoordinate2D(latitude: 1, longitude: 0)
        XCTAssertEqual(bearing(from: from, to: to), 0.0, accuracy: 0.1)
    }

    func testBearingEast() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let to   = CLLocationCoordinate2D(latitude: 0, longitude: 1)
        XCTAssertEqual(bearing(from: from, to: to), 90.0, accuracy: 0.1)
    }

    func testBearingSouth() {
        let from = CLLocationCoordinate2D(latitude: 1, longitude: 0)
        let to   = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        XCTAssertEqual(bearing(from: from, to: to), 180.0, accuracy: 0.1)
    }

    func testBearingWest() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 1)
        let to   = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        XCTAssertEqual(bearing(from: from, to: to), 270.0, accuracy: 0.1)
    }

    func testNormalizeDeltaShortestArc() {
        // 350 -> 10 should give delta +20, not -340
        XCTAssertEqual(normalizeAngleDelta(10 - 350), 20.0, accuracy: 0.001)
        // 10 -> 350 should give delta -20, not +340
        XCTAssertEqual(normalizeAngleDelta(350 - 10), -20.0, accuracy: 0.001)
    }
}
```

### PrivacyInfo.xcprivacy Minimum Content

```xml
<!-- Source: Apple Developer Documentation — Privacy Manifest Files -->
<!-- File: PrivacyInfo.xcprivacy (added to Xcode target's resources) -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Data collected by the app -->
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypePreciseLocation</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>       <!-- Not linked to user identity -->
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>       <!-- Not used for tracking -->
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>
    <!-- Required reason APIs: UserDefaults, file timestamps, etc. -->
    <!-- Core Location does NOT go here — it goes in CollectedDataTypes above -->
    <!-- Add entries here only if the app uses UserDefaults, disk space, etc. -->
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <!-- Add entries only for APIs listed in Apple's "required reason APIs" list -->
        <!-- For a minimal Phase 1 app with no UserDefaults usage: leave empty -->
    </array>
    <!-- App does not track users -->
    <key>NSPrivacyTracking</key>
    <false/>
</dict>
</plist>
```

**Critical distinction:** `NSPrivacyAccessedAPITypes` is for "required reason APIs" (UserDefaults, file timestamps, disk space, system boot time, active keyboard). Core Location itself is NOT in this list — it goes in `NSPrivacyCollectedDataTypes`. Confusing these two is a common mistake that causes validation errors.

**Info.plist addition required separately:**
```
NSLocationWhenInUseUsageDescription: "SouthYeast uses your location to find the nearest pizza and point you to it. Without location, the compass cannot work."
```

---

## Phase 1 Build Sequence

Build strictly in dependency order:

```
Step 1: Xcode project scaffold (01-01)
  - New SwiftUI app target, Swift 6, iOS 17 deployment target
  - PrivacyInfo.xcprivacy added and in target membership
  - NSLocationWhenInUseUsageDescription in Info.plist
  - Group structure: Services/, Models/, Views/, Math/
  - SouthYeastApp.swift with @State service instances

Step 2: BearingMath.swift (01-03 prerequisite — pure, no dependencies)
  - bearing(from:to:) -> Double
  - normalizeAngleDelta(_:) -> Double
  - BearingMathTests.swift with 5 unit tests
  - ALL TESTS MUST PASS before proceeding

Step 3: Place.swift model (01-03 prerequisite — pure value type)
  - Struct with id, name, coordinate, mapItem

Step 4: LocationService.swift (01-02)
  - @Observable @MainActor final class
  - CLLocationManager with delegate
  - Permission state machine
  - headingAccuracy gating
  - startUpdating() / stopUpdating()

Step 5: AppState.swift (01-03 — depends on LocationService + BearingMath)
  - selectedPlace: Place?
  - compassAngle: Double (accumulated)
  - isCalibrating: Bool
  - updateCompassAngle() method

Step 6: CompassView.swift (01-03 — depends on AppState)
  - Reads appState.compassAngle
  - rotationEffect + interpolatingSpring
  - CalibrationStateView branch

Step 7: ContentView.swift wiring (01-01)
  - Permission state routing
  - PermissionPrimingView (custom pre-prompt)
  - PermissionDeniedView with Settings deep-link
  - scenePhase lifecycle handling

Step 8: PlacesService.swift stub (01-02 supporting)
  - Hardcoded Place for Phase 1 compass testing
  - Real MKLocalSearch implementation deferred to Phase 2
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ObservableObject + @Published` | `@Observable` macro | iOS 17 / Swift 5.9 | Selective property observation; no cascade re-render on unread properties |
| `CLLocationManager` delegate without actor isolation | `nonisolated` + `Task { @MainActor in }` | Swift 6 (2024) | Compile-time concurrency safety instead of runtime crashes |
| `magneticHeading` for compass rotation | `trueHeading` (requires location updates running) | Long-standing; enforcement matters | Eliminates systematic 10-20 degree city-dependent error |
| Normalize to 0-360 for `rotationEffect` | Accumulated angle with delta normalization | Community pattern; no API change | Eliminates full-circle spin through north |
| CocoaPods | Swift Package Manager | Google deprecated CocoaPods Aug 2025 | SPM is the only supported manager for new projects |
| `@StateObject` in App struct | `@State` (for `@Observable`) | iOS 17 | `@StateObject` is for `ObservableObject` only |

**Deprecated/outdated:**
- `@ObservableObject + @Published`: Still works on iOS 17 but causes render thrashing with high-frequency updates. Do not use for LocationService.
- `CocoaPods`: Maintenance mode as of August 2025. Google's own iOS SDKs no longer support it.
- `manager.monitorSignificantLocationChanges()`: For "where am I" coarse location; not suitable for a compass app that needs more granular updates.

---

## Open Questions

1. **`CLLocation` Sendability**
   - What we know: Sources indicate `CLLocation` is `Sendable` as of iOS 14+. `CLHeading` is not.
   - What's unclear: This was not confirmed against the iOS 17 SDK header or Swift 6 compiler flags directly.
   - Recommendation: In the `didUpdateLocations` delegate, capture `CLLocation` inside the `Task` — if it produces a compiler warning, extract `coordinate` and `altitude` as scalars before the Task boundary.

2. **`interpolatingSpring` stiffness/damping tuning**
   - What we know: STACK.md documents stiffness 170, damping 26 as the recommended starting point for a physical compass feel. These were sourced from GetStream's SwiftUI spring guide.
   - What's unclear: These parameters are for a "compass needle snap" aesthetic. The pizza slice is a different visual shape — the parameters may need tuning to feel right with the specific pizza needle geometry.
   - Recommendation: Start with stiffness 170, damping 26. Plan an explicit tuning step after CompassView is rendering.

3. **PlacesService stub in Phase 1**
   - What we know: Phase 1 uses a hardcoded test place to validate compass mechanics, not real MKLocalSearch.
   - What's unclear: Whether a single hardcoded coordinate is sufficient to verify all compass correctness criteria, or if the carousel selection mechanic (COMP-05) needs at least 2 hardcoded places.
   - Recommendation: Provide 2-3 hardcoded nearby pizza coordinates so the "selecting a different card re-targets compass" success criterion (criterion 4) can be verified in Phase 1 without wiring real Places data.

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: `CLLocationManager`, `CLHeading`, `CLLocationManagerDelegate`, `startUpdatingHeading()`, `trueHeading`, `headingAccuracy`
- Apple Developer Documentation: `@Observable` macro migration guide, `@MainActor`, `Sendable`
- Apple Developer Documentation: `PrivacyInfo.xcprivacy`, `NSPrivacyCollectedDataTypes`, "Adding a Privacy Manifest to Your App"
- Apple Developer Documentation: `CLAuthorizationStatus`, "Requesting Authorization to Use Location Services"
- Apple Developer Forums thread/711646 — `NSToolbarDelegate and MainActor` (delegate isolation pattern)
- Movable Type Scripts: Spherical bearing formula (atan2 formula, established geodetic math)

### Secondary (MEDIUM confidence)
- The Inked Engineer: "Bridging CoreLocation to Swift 6 Concurrency" — `@unchecked Sendable` alternative pattern
- Jesse Squires (2024): SwiftUI app lifecycle issues with `ScenePhase` — confirms iOS behavior is reliable even where macOS is not
- Ottorino Bruni: PrivacyInfo.xcprivacy practical guide — `NSPrivacyCollectedDataTypes` structure
- SwiftUI Lab — Advanced Animations Part 2: GeometryEffect and `animatableData` pattern
- Project research files: ARCHITECTURE.md, PITFALLS.md, STACK.md (all previously verified against Apple docs)

### Tertiary (LOW confidence)
- Antoine van der Lee: "Approachable Concurrency in Swift 6.2" — Swift 6.2 eases some isolation requirements, but this app targets Swift 6.0 patterns for now

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Apple-native APIs; zero third-party; verified against official docs
- Architecture patterns: HIGH — `nonisolated` + `Task { @MainActor in }` is documented community consensus for Swift 6 + CLLocationManager; accumulated rotation is established compass pattern
- Bearing math: HIGH — standard geodetic formula; same formula in Apple developer forums, multiple reference implementations; unit-testable
- Permission state machine: HIGH — `CLAuthorizationStatus` enum is stable, documented; all states enumerated in Apple docs
- PrivacyInfo.xcprivacy: HIGH for structure; MEDIUM for exact `NSPrivacyAccessedAPITypes` needed (depends on which APIs the Phase 1 code actually uses — may be none)
- Pitfalls: HIGH — all sourced from PITFALLS.md which was verified against Apple docs; the 0/360 wrap and trueHeading issues are confirmed across multiple independent compass implementations

**Research date:** 2026-02-21
**Valid until:** 2026-05-21 (90 days; Core Location and SwiftUI APIs are stable; Swift 6.2 approachable concurrency may simplify some patterns if the project moves to 6.2 later)
