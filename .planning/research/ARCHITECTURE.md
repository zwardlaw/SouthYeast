# Architecture Patterns

**Project:** Take Me to Pizza (Pizza Compass iOS App)
**Researched:** 2026-02-21
**Domain:** iOS location + compass + places discovery

---

## Recommended Architecture

Take Me to Pizza has one job: open app, find pizza. This is a single-screen experience with coordinated real-time data streams (device heading + user location + places results). The architecture must make those streams easy to compose and keep the UI reactive without fighting SwiftUI.

**Pattern:** Service-layer MVVM with `@Observable` services injected via SwiftUI `@Environment`.

No coordinator needed (single screen app). No TCA needed (complexity is in data streams, not navigation state). MVVM with `@Observable` services is the right fit.

```
┌─────────────────────────────────────────────────────────────┐
│                       App Entry                             │
│                 TakeMeToPizzaApp.swift                         │
│   Bootstraps services, injects via @Environment            │
└─────────────┬───────────────────────────────────────────────┘
              │ @Environment injection
              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ContentView (Root)                       │
│              Observes AppState, routes layout               │
└──────┬────────────────────────┬───────────────┬────────────┘
       │                        │               │
       ▼                        ▼               ▼
┌─────────────┐   ┌─────────────────────┐  ┌───────────────┐
│  Compass    │   │   Card Carousel     │  │  Status / HUD │
│    View     │   │       View          │  │    overlay    │
└──────┬──────┘   └──────────┬──────────┘  └───────────────┘
       │                     │
       ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                      AppState                               │
│  @Observable — single source of truth for derived state     │
│  - selectedPlace: Place?                                    │
│  - compassAngle: Double                                     │
│  - mysteryMode: Bool                                        │
│  - permissionStatus: AuthStatus                             │
└──────┬────────────────────────────────────────────────────┬─┘
       │ reads                                              │ reads
       ▼                                                    ▼
┌─────────────────────┐                  ┌──────────────────────────┐
│   LocationService   │                  │     PlacesService        │
│   @Observable       │                  │     @Observable          │
│                     │                  │                          │
│ - location: CLLoc   │                  │ - places: [Place]        │
│ - heading: Double   │                  │ - isLoading: Bool        │
│                     │                  │ - error: Error?          │
│ startUpdating()     │                  │                          │
│ stopUpdating()      │                  │ searchNearby(loc, query) │
└─────────────────────┘                  └──────────────────────────┘
       │ CLLocationManager                        │ MKLocalSearch
       │ CLLocationUpdate.liveUpdates()           │ (async/await)
       ▼                                          ▼
  Device Hardware                         Apple Maps / MapKit
  (GPS + Magnetometer)                       Places Data
```

---

## Component Boundaries

| Component | Responsibility | Owns | Reads | Does NOT touch |
|-----------|---------------|------|-------|----------------|
| `LocationService` | Wraps CLLocationManager. Publishes location and heading as `@Observable` properties | CLLocationManager instance | Device hardware | UI, places data |
| `PlacesService` | Executes MKLocalSearch queries. Manages result pagination. Owns the `[Place]` array | MKLocalSearch, Place models | LocationService (for search region) | CLLocationManager directly, UI |
| `AppState` | Derives compass angle from heading + target. Holds selected place, mystery mode toggle, permission status | Computed bearing angle | LocationService + PlacesService | Hardware APIs directly |
| `CompassView` | Renders animated pizza slice. Applies rotationEffect | - | AppState.compassAngle | Business logic, services |
| `CarouselView` | Horizontal scroll of place cards. Triggers "load more" | Scroll position | AppState.selectedPlace, PlacesService.places | Compass rendering |
| `DesignSystem` | Tokens: colors, typography, spacing, border widths | Asset catalogs | - | Runtime state |
| `TakeMeToPizzaApp` | Bootstraps services, injects via `.environment()` | Service instances | - | UI layout |

---

## Data Flow

### Stream 1: Heading → Compass Rotation

This is the hot path. It runs on every heading update (roughly 10-20 Hz).

```
CLLocationManager
  └── didUpdateHeading (delegate callback)
        └── LocationService.heading = newHeading.trueHeading
              └── AppState observes heading
                    └── AppState.compassAngle = bearing(to: selectedPlace) - heading
                          └── CompassView.rotationEffect(compassAngle)
```

**Critical:** `bearing - heading` is the needle angle, not just the bearing. Device heading offsets the raw bearing so the pizza slice always points correctly relative to how the phone is held.

**Bearing formula (established trigonometry, HIGH confidence):**
```swift
func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let lat1 = from.latitude.degreesToRadians
    let lat2 = to.latitude.degreesToRadians
    let dLon = (to.longitude - from.longitude).degreesToRadians
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    return atan2(y, x).radiansToDegrees
}
```

### Stream 2: Location → Places Search

Triggered when location first becomes available, when it moves significantly, or manually on pull-to-refresh.

```
CLLocationUpdate.liveUpdates() (async sequence)
  └── LocationService.location = update.location
        └── AppState detects significant location change (>50m threshold)
              └── PlacesService.searchNearby(around: location, query: "pizza")
                    └── MKLocalSearch.start() (async/await)
                          └── PlacesService.places = results
                                └── CarouselView renders cards
                                └── AppState.selectedPlace = places.first (auto-select nearest)
```

### Stream 3: Place Selection → Compass Retarget

```
User taps card in CarouselView
  └── AppState.selectedPlace = tappedPlace
        └── AppState.compassAngle recomputes (bearing to new target)
              └── CompassView animates to new angle (withAnimation)
```

### Stream 4: Navigation Handoff

```
User taps "Directions" on card
  └── MKMapItem(placemark: ...).openInMaps(launchOptions: [
        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault
      ])
```
No view model needed. Direct call from button action. MKMapItem already exists on the `Place` model.

### Stream 5: Mystery Mode

```
User toggles mystery mode
  └── AppState.mysteryMode.toggle()
        └── CarouselView reads mysteryMode, renders [PIZZA] instead of name
        └── CompassView still rotates (bearing unchanged)
```

---

## Service Layer Details

### LocationService

```swift
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var location: CLLocation?
    var heading: Double = 0          // trueHeading degrees
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    func startUpdating() {
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
        manager.headingFilter = 1.0  // only fire if heading changes >1 degree
    }
}
```

**Why delegate pattern (not async liveUpdates) for heading:** As of 2025, `CLLocationUpdate.liveUpdates()` covers position but heading still requires `startUpdatingHeading()` + `locationManager(_:didUpdateHeading:)` delegate callback. The delegate pattern wraps cleanly into `@Observable`.

**Why NOT a singleton:** The app has one screen. `LocationService` lives as a single instance bootstrapped at app launch and injected via `@Environment`. Singleton pattern is an anti-pattern here — it hides dependencies and complicates testing.

### PlacesService

```swift
@Observable
final class PlacesService {
    var places: [Place] = []
    var isLoading: Bool = false
    var error: Error?

    func searchNearby(around location: CLLocation, query: String = "pizza") async {
        isLoading = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            places = response.mapItems.map(Place.init)
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
```

**Pagination note:** MKLocalSearch does not support cursor-based pagination. Results are limited per query (typically 10-25 items for a given region). To "load more," shrink the search region or use a different query. For MVP this is fine. Post-MVP, Google Places API supports true pagination via page tokens if more results are needed.

### AppState

```swift
@Observable
final class AppState {
    var selectedPlace: Place?
    var mysteryMode: Bool = false

    var compassAngle: Double {
        guard let place = selectedPlace,
              let location = locationService.location else { return 0 }
        let bear = bearing(from: location.coordinate, to: place.coordinate)
        return bear - locationService.heading
    }

    private let locationService: LocationService
    private let placesService: PlacesService

    init(locationService: LocationService, placesService: PlacesService) {
        self.locationService = locationService
        self.placesService = placesService
    }
}
```

`AppState` reads from services but does not own them. It is the composition layer, not a god object.

---

## Design System Architecture

The neobrutalist design system should be a separate file/group (not a separate package for MVP).

```
DesignSystem/
  Colors.swift         // Color tokens: NBColor.background, .border, .accent
  Typography.swift     // Font tokens: NBFont.headline, .body, .label
  Spacing.swift        // Spacing scale: NBSpacing.sm, .md, .lg
  BorderWidth.swift    // NBBorder.thick (3pt), .thicker (5pt)
  ViewModifiers.swift  // .nbCard(), .nbButton() — reusable style modifiers
```

**Injection pattern:** Use static properties on a `DesignSystem` enum, not environment injection. Design tokens don't change at runtime for this app.

```swift
extension Color {
    static let nbBackground = Color("NBBackground")  // from asset catalog
    static let nbBorder = Color("NBBorder")
    static let nbPrimary = Color("NBPrimary")
}
```

---

## Patterns to Follow

### Pattern 1: Services as @Observable Singletons-of-One

**What:** Create one instance of each service at app entry, inject via `.environment()`.

**Why:** SwiftUI `@Environment` provides dependency injection without global state. Views read services without coupling to concrete types. Testable by injecting mock services.

```swift
@main
struct TakeMeToPizzaApp: App {
    @State private var locationService = LocationService()
    @State private var placesService = PlacesService()
    @State private var appState: AppState

    init() {
        let loc = LocationService()
        let places = PlacesService()
        _locationService = State(initialValue: loc)
        _placesService = State(initialValue: places)
        _appState = State(initialValue: AppState(locationService: loc, placesService: places))
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

### Pattern 2: Derived State in AppState, Not in Views

**What:** Compass angle computation lives in `AppState`, not inside `CompassView`.

**Why:** Views should only bind and render. Logic in views cannot be tested. AppState can be unit tested independently.

**Example:**
```swift
// GOOD: AppState computes, CompassView binds
CompassView(angle: appState.compassAngle)

// BAD: CompassView does its own bearing math
// struct CompassView { func bearing(to place:...) -> Double { ... } }
```

### Pattern 3: Place Model Wraps MKMapItem

**What:** Define a `Place` struct that wraps `MKMapItem`. Do not pass `MKMapItem` into SwiftUI views.

**Why:** `MKMapItem` is a reference type not suitable for SwiftUI state. A `Place` value type is diffable, hashable, and testable.

```swift
struct Place: Identifiable, Hashable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let address: String?
    let mapItem: MKMapItem          // retained for openInMaps()
}
```

### Pattern 4: Heading Filter to Avoid Thrashing

**What:** Set `manager.headingFilter = 1.0` (degrees). Don't redraw on sub-degree changes.

**Why:** Heading fires 20+ times per second without filtering. SwiftUI diffing handles it, but the battery cost is real and the animation will jitter on small changes.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: God ViewModel

**What:** A single `ViewModel` that owns location, heading, places, selected place, compass angle, mystery mode, and UI state.

**Why bad:** Untestable monolith. A heading update triggers diffing across ALL properties. Hard to isolate failures.

**Instead:** Separate services (`LocationService`, `PlacesService`) with thin `AppState` as composition layer.

### Anti-Pattern 2: Computing Bearing in the View

**What:** `CompassView` does `atan2(...)` on each redraw.

**Why bad:** Math in views is untestable. Views redraw frequently; if the math is wrong, debugging is painful.

**Instead:** `AppState.compassAngle` is a computed property that can be unit tested independently.

### Anti-Pattern 3: Storing MKMapItem Arrays as View State

**What:** `@State var results: [MKMapItem]` inside `CarouselView`.

**Why bad:** `MKMapItem` is a reference type with no stable identity in SwiftUI. `ForEach` over `MKMapItem` arrays is fragile.

**Instead:** Immediately map to `[Place]` value types in `PlacesService`.

### Anti-Pattern 4: Using CLLocationManager Directly in Views

**What:** Any SwiftUI view creating its own `CLLocationManager`.

**Why bad:** Multiple managers = multiple permission prompts, battery drain, conflicting delegate callbacks.

**Instead:** One `LocationService`, one manager, injected everywhere.

### Anti-Pattern 5: Continuous Location Updates Without Significant-Change Filtering

**What:** Re-querying places on every location update.

**Why bad:** `startUpdatingLocation()` fires many times per second. Searching places on every tick hammers the API and kills battery.

**Instead:** Only re-search when location changes by a meaningful threshold (50-100 meters) using distance comparison.

### Anti-Pattern 6: Animating rotationEffect with raw heading changes

**What:** Applying each raw heading value directly as a rotation without normalization.

**Why bad:** Heading wraps 0-360. Going from 359 to 1 degrees causes the compass to spin 358 degrees the wrong way instead of 2 degrees the right way.

**Instead:** Normalize the angle difference to the shortest rotation path:
```swift
func normalizedAngle(_ angle: Double) -> Double {
    var a = angle.truncatingRemainder(dividingBy: 360)
    if a > 180 { a -= 360 }
    if a < -180 { a += 360 }
    return a
}
```

---

## Component Build Order (Dependency Map)

Components must be built in order of their dependencies:

```
Layer 0 (no dependencies):
  DesignSystem (tokens, modifiers)
  Place model (value type, no service dependency)

Layer 1 (depends on Layer 0):
  LocationService (wraps CLLocationManager)
  PlacesService (wraps MKLocalSearch, uses Place model)

Layer 2 (depends on Layer 1):
  AppState (composes LocationService + PlacesService)
  Bearing math utilities (pure functions, testable)

Layer 3 (depends on Layer 2):
  CompassView (reads AppState.compassAngle)
  CarouselView (reads PlacesService.places, AppState.selectedPlace)

Layer 4 (composes Layer 3):
  ContentView (layouts CompassView + CarouselView)
  TakeMeToPizzaApp (bootstraps and injects services)
```

**Implication for phases:**
- Phase 1 can build LocationService + PlacesService + Place model independently of UI
- Phase 2 builds CompassView in isolation with hardcoded/mock data
- Phase 3 wires the real services to real UI
- The carousel and design system can be developed in parallel with compass logic

---

## Scalability Considerations

| Concern | MVP (single city) | Scale (multi-city) | Notes |
|---------|------------------|-------------------|-------|
| Places data source | MKLocalSearch (free) | Google Places API | MKLocalSearch is region-limited, ~10-25 results |
| Heading updates | CLLocationManager delegate | No change needed | Hardware-bound, already optimal |
| Result count | 10-25 via MKLocalSearch | 60+ via Google Places pagination | Google Places supports page tokens |
| Caching | None | NSCache for recent searches | Only needed if search becomes slow |
| Background location | Not needed | Not needed | This app is foreground-only |

---

## Sources

- [Getting Heading and Course Information — Apple Developer](https://developer.apple.com/documentation/corelocation/getting-heading-and-course-information) (HIGH confidence — official Apple documentation)
- [How to Build a Compass App in Swift — Five Stars](https://www.fivestars.blog/articles/build-compass-app-swift/) (HIGH confidence — verified against CoreLocation docs)
- [CLHeading — Apple Developer Documentation](https://developer.apple.com/documentation/corelocation/clheading) (HIGH confidence — official)
- [Streamlined Location Updates with CLLocationUpdate — WWDC23 summary](https://medium.com/simform-engineering/streamlined-location-updates-with-cllocationupdate-in-swift-wwdc23-2200ef71f845) (MEDIUM confidence — WWDC-sourced, but secondary)
- [The Future of Accessing User Location in SwiftUI — Holy Swift](https://holyswift.app/the-new-way-to-get-current-user-location-in-swiftu-tutorial/) (MEDIUM confidence — aligns with WWDC23 changes)
- [Searching for Points of Interest in MapKit with SwiftUI — Create with Swift](https://www.createwithswift.com/searching-points-interest-mapkit-swiftui/) (HIGH confidence — verified with MKLocalSearch docs)
- [MKLocalSearch.Request — Apple Developer Documentation](https://developer.apple.com/documentation/mapkit/mklocalsearch/request) (HIGH confidence — official)
- [openInMaps(launchOptions:) — Apple Developer Documentation](https://developer.apple.com/documentation/mapkit/mkmapitem/1452239-openinmaps) (HIGH confidence — official)
- [Sharing @Observable Objects Through SwiftUI's Environment — Hacking with Swift](https://www.hackingwithswift.com/books/ios-swiftui/sharing-observable-objects-through-swiftuis-environment) (HIGH confidence — well-known SwiftUI resource)
- [HeadingIndicator SwiftUI Package — kiliankoe/HeadingIndicator](https://github.com/kiliankoe/HeadingIndicator) (MEDIUM confidence — open source reference implementation)
- [The Ultimate Guide to Modern iOS Architecture in 2025 — Medium](https://medium.com/@csmax/the-ultimate-guide-to-modern-ios-architecture-in-2025-9f0d5fdc892f) (LOW confidence — secondary blog post, not verified against official docs)
- [Rotation Animation Normalization — Multiple community sources](https://softwareanders.com/swiftui-rotation-animation/) (MEDIUM confidence — well-known compass gotcha, verified across multiple compass tutorials)
