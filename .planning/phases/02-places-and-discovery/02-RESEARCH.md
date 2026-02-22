# Phase 2: Places and Discovery - Research

**Researched:** 2026-02-21
**Domain:** MKLocalSearch, SwiftUI Carousel, Haptics, Network Monitoring, Deep Links
**Confidence:** MEDIUM-HIGH (Apple docs blocked JS, key findings verified via multiple community sources)

---

## Summary

Phase 2 replaces the Phase 1 stub PlacesService (3 hardcoded places) with a live MKLocalSearch integration and replaces the PlacePickerRow with a full snap-to-card carousel. The existing @Observable/@MainActor/environment injection architecture from Phase 1 carries forward unchanged — new services follow the same pattern.

MKLocalSearch is free, requires no API key, and supports async/await natively. It does NOT have pagination — each request returns at most ~10 results. "Infinite scroll" must be simulated by expanding the search region and re-querying when the user nears the end of the list. MKMapItem does not expose star ratings or opening hours as typed properties — those fields are not in the public API. The expanded card should display name, address (via placemark), phone, website URL, and point-of-interest category; hours and rating must be omitted or obtained via a MapKit Place Card sheet if desired.

The carousel is built with `scrollTargetBehavior(.viewAligned)` + `scrollTargetLayout()` (iOS 17+), which handles snapping natively. ScrollPosition with `scrollPosition(id:)` tracks the centered card and drives the compass retarget. Haptics use `.sensoryFeedback(.impact, trigger:)` (iOS 17+), the pure-SwiftUI path that requires no UIKit import. Network monitoring uses NWPathMonitor wrapped in a `@Observable @MainActor` class, consistent with Phase 1 service patterns.

**Primary recommendation:** Build PlacesService as a standalone `@Observable @MainActor` class injected via `.environment()`, following the exact pattern of LocationService. The carousel lives in its own CarouselView file, replacing PlacePickerRow in CompassView.

---

## Standard Stack

### Core — No additions required (zero third-party deps preserved)

| Library / Framework | Purpose | Notes |
|---|---|---|
| MapKit | MKLocalSearch, MKMapItem, MKLocalSearch.Request, MKPointOfInterestFilter | Ships with iOS — import MapKit |
| Network | NWPathMonitor for connectivity detection | Ships with iOS — import Network |
| SwiftUI | ScrollView, scrollTargetBehavior, ScrollPosition, sensoryFeedback | iOS 17+ APIs used |
| Foundation | URL construction for deep links | Ships with iOS |

### No new dependencies needed

All Phase 2 requirements are satisfied by Apple frameworks. Zero third-party additions.

**Installation:** No `npm install` equivalent — frameworks ship with Xcode.

---

## Architecture Patterns

### Recommended File Structure

```
TakeMeToPizza/
├── Models/
│   ├── Place.swift          # Expand with MKMapItem fields
│   └── AppState.swift       # No changes needed for Phase 2
├── Services/
│   ├── LocationService.swift # No changes needed
│   ├── PlacesService.swift   # Replace stub with MKLocalSearch
│   └── NetworkMonitor.swift  # New — NWPathMonitor wrapper
├── Views/
│   ├── CompassView.swift     # Replace PlacePickerRow with CarouselView
│   └── CarouselView.swift    # New — all carousel + card logic
├── Math/
│   └── BearingMath.swift     # No changes needed
├── ContentView.swift         # Add NetworkMonitor to environment
└── TakeMeToPizzaApp.swift    # Allocate NetworkMonitor alongside other services
```

### Pattern 1: PlacesService with MKLocalSearch

**What:** `@Observable @MainActor` class with async `fetchNearby()` that queries MKLocalSearch with the current user location as the region center. Sorts results by distance. Expands region and re-queries for "load more."

**When to use:** Called on first location fix and whenever user scrolls near end of place list.

```swift
// Source: verified pattern from multiple community articles + Apple async/await docs
import MapKit
import Observation
import CoreLocation

@Observable
@MainActor
final class PlacesService {
    var places: [Place] = []
    var isLoading = false
    var error: PlacesError?

    private var searchRegionRadiusKm: Double = 1.0
    private let radiusStepKm: Double = 1.0
    private let maxRadiusKm: Double = 10.0

    func fetchNearby(userLocation: CLLocation) async {
        isLoading = true
        error = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "pizza"
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant])
        request.region = MKCoordinateRegion(
            center: userLocation.coordinate,
            latitudinalMeters: searchRegionRadiusKm * 1000,
            longitudinalMeters: searchRegionRadiusKm * 1000
        )

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            let sorted = response.mapItems
                .sorted { a, b in
                    let locA = CLLocation(latitude: a.placemark.coordinate.latitude,
                                         longitude: a.placemark.coordinate.longitude)
                    let locB = CLLocation(latitude: b.placemark.coordinate.latitude,
                                         longitude: b.placemark.coordinate.longitude)
                    return userLocation.distance(from: locA) < userLocation.distance(from: locB)
                }
                .map { Place(from: $0, userLocation: userLocation) }
            places = sorted
        } catch {
            self.error = .searchFailed(error)
        }
        isLoading = false
    }

    func loadMore(userLocation: CLLocation) async {
        guard searchRegionRadiusKm < maxRadiusKm else { return }
        searchRegionRadiusKm += radiusStepKm
        await fetchNearby(userLocation: userLocation)
    }
}
```

### Pattern 2: Place Model — Expanded from Stub

**What:** Replace the UUID-keyed stub with an MKMapItem-backed value type. MKMapItem does NOT provide star ratings or hours — omit those fields.

**Available MKMapItem fields (confirmed):**
- `name` — business name (String?)
- `phoneNumber` — phone number (String?)
- `url` — website URL (URL?)
- `placemark.coordinate` — CLLocationCoordinate2D
- `placemark.thoroughfare` — street name
- `placemark.subThoroughfare` — street number
- `placemark.locality` — city
- `placemark.administrativeArea` — state
- `placemark.postalCode` — zip
- `pointOfInterestCategory` — MKPointOfInterestCategory (e.g., `.restaurant`)

**Not available in MKMapItem public API:**
- Star rating — NOT present
- Opening hours — NOT present (MapKit shows them in Place Cards but does not expose them programmatically)
- Price level — NOT present

```swift
// Source: verified against multiple community sources and NSHipster MKLocalSearch article
import Foundation
import CoreLocation
import MapKit

struct Place: Identifiable, Equatable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let phoneNumber: String?
    let websiteURL: URL?
    let address: String          // formatted from placemark components
    let distanceMeters: Double   // calculated at fetch time, refreshed on location update

    // Derived display value — pizza slices unit, ~0.2032 meters per slice (8 inches)
    var distanceInPizzaSlices: Int {
        Int((distanceMeters / 0.2032).rounded())
    }

    static func == (lhs: Place, rhs: Place) -> Bool { lhs.id == rhs.id }

    init(from mapItem: MKMapItem, userLocation: CLLocation) {
        self.id = UUID()
        self.name = mapItem.name ?? "Unknown"
        self.coordinate = mapItem.placemark.coordinate
        self.phoneNumber = mapItem.phoneNumber
        self.websiteURL = mapItem.url
        let pm = mapItem.placemark
        var parts: [String] = []
        if let sub = pm.subThoroughfare { parts.append(sub) }
        if let street = pm.thoroughfare { parts.append(street) }
        if let city = pm.locality { parts.append(city) }
        self.address = parts.joined(separator: " ")
        let placeLocation = CLLocation(latitude: coordinate.latitude,
                                       longitude: coordinate.longitude)
        self.distanceMeters = userLocation.distance(from: placeLocation)
    }
}
```

### Pattern 3: Snap-to-Card Carousel

**What:** Horizontal ScrollView with `scrollTargetBehavior(.viewAligned)` + `scrollTargetLayout()` for native snapping. `scrollPosition(id:)` binding tracks the centered card and drives `appState.selectedPlace`.

**When to use:** This is the primary UI component replacing PlacePickerRow in CompassView.

```swift
// Source: HackingWithSwift carousel tutorial + Livsy Code peek carousel article
import SwiftUI

struct CarouselView: View {
    @Environment(AppState.self) private var appState
    @Environment(PlacesService.self) private var placesService
    @State private var scrollID: UUID?
    @State private var expandedID: UUID?

    var body: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            // Card width: full width minus peeking margin on each side
            let cardWidth = totalWidth - 80  // 40pt peek on each side

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(placesService.places) { place in
                        CardView(
                            place: place,
                            isExpanded: expandedID == place.id,
                            onTap: { expandedID = (expandedID == place.id) ? nil : place.id }
                        )
                        .frame(width: cardWidth)
                        .id(place.id)
                    }
                }
                // Horizontal padding centers first/last card with same peek margin
                .padding(.horizontal, (totalWidth - cardWidth) / 2)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollID)
            .onChange(of: scrollID) { _, newID in
                guard let id = newID,
                      let place = placesService.places.first(where: { $0.id == id }) else { return }
                appState.selectedPlace = place
            }
        }
        .frame(height: 140)  // Collapsed card height; expanded handled in CardView
    }
}
```

**Carousel placement in CompassView:** The carousel overlays the compass as a translucent strip pinned to the bottom of the screen using a `ZStack` with `.frame(maxHeight: .infinity, alignment: .bottom)` — not a VStack split.

### Pattern 4: Card Expand Animation

**What:** Card grows in place upward when tapped. No sheet or modal. Driven by `@State isExpanded` changing card height inside `withAnimation`.

```swift
// Source: SwiftUI animation basics — withAnimation + conditional frame is idiomatic
struct CardView: View {
    let place: Place
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsed content — always visible
            Text(place.name)
                .font(.headline)
            Text("\(place.distanceInPizzaSlices.formatted()) slices away")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isExpanded {
                // Expanded-only content
                Divider()
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.caption)
                }
                if let phone = place.phoneNumber {
                    Text(phone)
                        .font(.caption)
                }
                Button("Get Directions") {
                    openDirections(to: place)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                onTap()
            }
        }
    }
}
```

**Note:** `matchedGeometryEffect` is for source-to-destination transitions (e.g., list → full screen). For in-place growth, `withAnimation` on a conditional height is the correct pattern and simpler.

### Pattern 5: Directions Deep Link

**What:** Check if Google Maps is installed; open with walking directions. Fall back to Apple Maps.

**Decision from CONTEXT.md:** Ask user once which maps app to use, store with `@AppStorage`.

```swift
// Source: Google Maps iOS URL Scheme documentation (developers.google.com/maps)
// Source: Apple Maps URL Scheme reference (developer.apple.com/library)
import UIKit

enum PreferredMapsApp: String, Sendable {
    case google
    case apple
}

func openDirections(to place: Place) {
    // Try Google Maps first if preferred and installed
    let googleScheme = "comgooglemaps://"
    let lat = place.coordinate.latitude
    let lng = place.coordinate.longitude

    if preferredApp == .google,
       let checkURL = URL(string: googleScheme),
       UIApplication.shared.canOpenURL(checkURL),
       let url = URL(string: "\(googleScheme)?saddr=&daddr=\(lat),\(lng)&directionsmode=walking") {
        UIApplication.shared.open(url)
        return
    }

    // Apple Maps fallback (always available)
    if let url = URL(string: "http://maps.apple.com/?daddr=\(lat),\(lng)&dirflg=w") {
        UIApplication.shared.open(url)
    }
}
```

**Info.plist requirement:** Must declare `LSApplicationQueriesSchemes` with `comgooglemaps` to call `canOpenURL` on the Google Maps scheme. Without this, `canOpenURL` always returns `false` on iOS 9+.

```xml
<!-- Add to Info.plist -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>comgooglemaps</string>
</array>
```

### Pattern 6: Maps App Preference Storage

**What:** `@AppStorage` with a `String`-raw-valued enum. Works natively on iOS 17+ with Swift 6.

```swift
// Source: DeveloperMemos @AppStorage enum article (verified pattern)
enum PreferredMapsApp: String, Sendable {
    case google
    case apple
}

struct CardView: View {
    @AppStorage("preferredMapsApp") private var preferredApp: PreferredMapsApp = .apple
    // ...
}
```

**Where to show the picker:** Show a one-time sheet the first time the user taps "Get Directions." Store a separate `@AppStorage("hasChosenMapsApp") var hasChosen: Bool = false` flag to gate it.

### Pattern 7: Haptic on Compass Alignment (COMP-03)

**What:** `.sensoryFeedback(.impact(flexibility: .rigid), trigger:)` fires when compass aligns with target direction. iOS 17+ SwiftUI-native. No UIKit import needed.

**Alignment detection:** In `AppState.updateCompassAngle()`, the raw angle delta approaches 0 when pointing at target. Define "aligned" as `abs(rawAngle % 360) < 5` (within 5 degrees).

```swift
// Source: HackingWithSwift sensoryFeedback tutorial
// Applied to the compass needle view
.sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7), trigger: appState.isAligned)
```

Add `isAligned: Bool` computed property to AppState:

```swift
var isAligned: Bool {
    // True when needle is within 5 degrees of target direction
    abs((previousRawAngle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) - 0) < 5
}
```

**Debounce consideration:** `sensoryFeedback` triggers on every value change. Use a debounced bool (e.g., only flip from false→true, reset after 2s) to avoid continuous buzzing when perfectly aligned.

### Pattern 8: Network Monitor Service

**What:** `@Observable @MainActor` NWPathMonitor wrapper, injected via environment alongside other services. Matches Phase 1 service pattern exactly.

```swift
// Source: HolySwift @Observable NWPathMonitor article (verified against Network framework docs)
import Network
import Observation

@Observable
@MainActor
final class NetworkMonitor {
    var isConnected = true

    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor", qos: .userInitiated))
    }

    deinit {
        monitor.cancel()
    }
}
```

Add to `TakeMeToPizzaApp`:

```swift
@State private var networkMonitor: NetworkMonitor

init() {
    // existing init pattern...
    _networkMonitor = State(initialValue: NetworkMonitor())
}

var body: some Scene {
    WindowGroup {
        ContentView()
            .environment(locationService)
            .environment(placesService)
            .environment(appState)
            .environment(networkMonitor)  // Add this
    }
}
```

### Pattern 9: Distance in Pizza Slices

**What:** Pure computation. 1 pizza slice ≈ 8 inches = 0.2032 meters.

```swift
// No library needed — pure math
extension Place {
    // 8 inches per slice = 0.2032 meters
    private static let metersPerSlice: Double = 0.2032

    var distanceInPizzaSlices: Int {
        Int((distanceMeters / Self.metersPerSlice).rounded())
    }

    var distanceDisplayString: String {
        "\(distanceInPizzaSlices.formatted()) slices away"
    }
}
```

**Note:** `distanceMeters` must be refreshed when `locationService.location` changes (DISC-06). PlacesService should recompute distances in-place without re-fetching search results on every location update — just recalculate the `distanceMeters` field on each Place.

### Anti-Patterns to Avoid

- **Splitting the screen:** Compass + carousel in a VStack. The carousel overlays the compass in a ZStack. The compass always takes the full screen behind it.
- **Using a Sheet for card expand:** The CONTEXT.md decision is explicit: card grows in place, no sheet or modal.
- **matchedGeometryEffect for card expand:** That pattern is for source→destination transitions. In-place height animation with `withAnimation` is correct and simpler.
- **Re-querying MKLocalSearch on every location update:** Only re-query on the 50m threshold (already wired into LocationService distanceFilter). Recalculate distances in-place on cheaper location updates.
- **Assuming MKLocalSearch has pagination:** It doesn't. Strategy is expand-region and re-query.
- **Accessing AppStorage from service layer:** @AppStorage belongs in views only. Pass the preference value into functions.
- **CLHeading across actor boundaries:** Phase 1 already enforces this. PlacesService works with CLLocation (which IS Sendable), so no new risk here.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Snap-to-card scrolling | Custom drag gesture + offset math | `scrollTargetBehavior(.viewAligned)` | Native, correct, accessibility-aware, iOS 17+ |
| Network reachability | Polling / URLSession ping | `NWPathMonitor` | System-level, battery-efficient, instant notification |
| Haptic timing | `DispatchQueue.asyncAfter` + UIKit | `.sensoryFeedback` modifier | Declarative, no UIKit import, SwiftUI-native |
| Distance units | Custom string formatting | `Int.formatted()` + computed property | Standard formatting, locale-aware commas |
| Place search | Custom HTTP client to any API | `MKLocalSearch` | Free, no key, on-device, works offline with cached data |

**Key insight:** iOS 17's SwiftUI carousel APIs are good enough that any custom implementation will be harder to maintain and less accessible.

---

## Common Pitfalls

### Pitfall 1: MKLocalSearch Returns ~10 Results (Not More)

**What goes wrong:** Developer expects `DISC-05` (load 10 + auto-load 10 more) to work like a paginated API. MKLocalSearch does not support cursors or offsets.

**Why it happens:** The API returns "all available results" in one response, but Apple's backend caps this at roughly 10 results for a given region+query.

**How to avoid:** "Load more" means expanding the search region (`searchRegionRadiusKm += 1.0`) and re-querying. Deduplicate results by coordinate or name. Cap expansion at a sensible radius (10km for a city).

**Warning signs:** Second search returns the same 10 places as the first.

### Pitfall 2: MKMapItem Has No Rating or Hours

**What goes wrong:** Developer assumes MapKit exposes ratings and opening hours as typed properties, similar to Google Places API.

**Why it happens:** MapKit shows hours in the Place Card UI but does not expose them programmatically in the public API.

**How to avoid:** Expanded card shows: name, address, phone, website URL. Do not show rating or hours fields. Do not fetch from Google Places in Phase 2 (that is the escalation path documented in STATE.md, not current scope).

**Warning signs:** Searching Swift headers for `openingHours` or `rating` finds nothing on MKMapItem.

### Pitfall 3: `canOpenURL` Always Returns False for Google Maps Without Info.plist Entry

**What goes wrong:** Google Maps check silently fails, app always opens Apple Maps even when Google Maps is installed.

**Why it happens:** iOS 9+ requires apps to declare checked URL schemes in `LSApplicationQueriesSchemes` in Info.plist.

**How to avoid:** Add `comgooglemaps` to `LSApplicationQueriesSchemes` before testing the Google Maps deep link.

**Warning signs:** `canOpenURL` returns false on physical device with Google Maps installed.

### Pitfall 4: ScrollPosition onChange Fires Too Eagerly

**What goes wrong:** `onChange(of: scrollID)` fires during programmatic scroll, causing compass to jump mid-animation when `appState.selectedPlace` changes.

**Why it happens:** Programmatic scroll (triggered by place list update) updates `scrollID`, which triggers the onChange handler, which sets `selectedPlace`, which triggers compass update.

**How to avoid:** Use a `isUserScrolling` flag or debounce the onChange before setting `appState.selectedPlace`. Only drive the compass from user-initiated card changes, not programmatic ones.

**Warning signs:** Compass spins unexpectedly when new places load or when the carousel scrolls programmatically.

### Pitfall 5: Distance Not Updating as User Moves (DISC-06)

**What goes wrong:** Distance values on cards freeze after initial fetch.

**Why it happens:** `distanceMeters` is calculated once at fetch time and stored in Place. LocationService.location updates every 50m (distanceFilter), but Place values are immutable.

**How to avoid:** PlacesService needs a `updateDistances(userLocation:)` method that rebuilds Place values without re-querying MKLocalSearch. Call it from ContentView's `onChange(of: locationService.location)` handler (already exists for heading updates).

**Warning signs:** Distance displayed when standing still matches distance displayed after walking two blocks.

### Pitfall 6: Swift 6 Concurrency — NWPathMonitor Callback Thread

**What goes wrong:** `@Observable @MainActor` class properties are mutated from the NWPathMonitor background queue, causing Swift 6 concurrency violation.

**Why it happens:** NWPathMonitor calls `pathUpdateHandler` on whatever queue you pass to `start(queue:)`.

**How to avoid:** Wrap property mutations in `Task { @MainActor in ... }` inside the handler (shown in code example above). This is the same pattern used in LocationService for CLLocationManagerDelegate callbacks.

**Warning signs:** Xcode Swift 6 mode reports "actor-isolated property mutated from outside actor."

### Pitfall 7: MKLocalSearch Rate Limit

**What goes wrong:** Rapid re-queries (e.g., expanding region on every location update) hit Apple's documented 50 requests/minute limit and return errors.

**Why it happens:** Each call to `loadMore()` triggers a new MKLocalSearch request. If triggered too frequently, requests get throttled.

**How to avoid:** Gate `loadMore()` behind the same 50m location threshold used for LocationService's `distanceFilter`. Only call `fetchNearby()` when location moves >= 50m. Debounce carousel scroll-end detection with a 500ms delay.

---

## Code Examples

### MKLocalSearch Full Query Setup

```swift
// Source: Verified against Apple MKLocalSearch.Request documentation reference
// + multiple community tutorials (polpiella.dev, createwithswift.com)
let request = MKLocalSearch.Request()
request.naturalLanguageQuery = "pizza"
request.resultTypes = .pointOfInterest
request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant])
request.region = MKCoordinateRegion(
    center: userLocation.coordinate,
    latitudinalMeters: 1000,   // 1km radius
    longitudinalMeters: 1000
)

let search = MKLocalSearch(request: request)
let response = try await search.start()
// response.mapItems: [MKMapItem] — ~10 results, already sorted by relevance
```

### Sorting MKMapItems by Distance

```swift
// Source: verified pattern (appsloveworld.com + multiple forums)
let sorted = response.mapItems.sorted { a, b in
    let locA = CLLocation(latitude: a.placemark.coordinate.latitude,
                          longitude: a.placemark.coordinate.longitude)
    let locB = CLLocation(latitude: b.placemark.coordinate.latitude,
                          longitude: b.placemark.coordinate.longitude)
    return userLocation.distance(from: locA) < userLocation.distance(from: locB)
}
```

### Peek Carousel with Snapping

```swift
// Source: HackingWithSwift scrollTargetBehavior tutorial
// + Livsy Code peek carousel article
ScrollView(.horizontal, showsIndicators: false) {
    LazyHStack(spacing: 12) {
        ForEach(items) { item in
            CardView(item: item)
                .frame(width: cardWidth)
                .id(item.id)
        }
    }
    .padding(.horizontal, peekPadding)   // Centers first/last card
    .scrollTargetLayout()
}
.scrollTargetBehavior(.viewAligned)
.scrollPosition(id: $scrollID)
```

### sensoryFeedback for Compass Alignment

```swift
// Source: HackingWithSwift sensoryFeedback guide (iOS 17+)
CompassNeedleView()
    .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7),
                     trigger: appState.isAligned)
```

### Google Maps + Apple Maps Direction Fallback

```swift
// Source: Google Maps iOS URL Scheme docs + Apple Maps URL Scheme reference
func openDirections(to place: Place, preferredApp: PreferredMapsApp) {
    let lat = place.coordinate.latitude
    let lng = place.coordinate.longitude

    if preferredApp == .google,
       let checkURL = URL(string: "comgooglemaps://"),
       UIApplication.shared.canOpenURL(checkURL),
       let url = URL(string: "comgooglemaps://?saddr=&daddr=\(lat),\(lng)&directionsmode=walking") {
        UIApplication.shared.open(url)
        return
    }

    // Apple Maps: dirflg=w = walking mode, omit saddr = current location
    if let url = URL(string: "http://maps.apple.com/?daddr=\(lat),\(lng)&dirflg=w") {
        UIApplication.shared.open(url)
    }
}
```

### NWPathMonitor Observable Service

```swift
// Source: HolySwift @Observable NWPathMonitor article
import Network
import Observation

@Observable
@MainActor
final class NetworkMonitor {
    var isConnected = true

    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor", qos: .userInitiated))
    }

    deinit { monitor.cancel() }
}
```

### AppStorage Enum for Maps Preference

```swift
// Source: DeveloperMemos @AppStorage enum article
enum PreferredMapsApp: String, Sendable {
    case google = "google"
    case apple  = "apple"
}

struct SomeView: View {
    @AppStorage("preferredMapsApp") private var preferredApp: PreferredMapsApp = .apple
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| UIScrollView + custom snap gesture | `scrollTargetBehavior(.viewAligned)` | iOS 17 (2023) | Native, no custom delegate |
| `UIImpactFeedbackGenerator.impactOccurred()` | `.sensoryFeedback` modifier | iOS 17 (2023) | Pure SwiftUI, no UIKit import |
| Reachability (third-party) | `NWPathMonitor` | iOS 12 (2018) | Built-in Network framework |
| `CLGeocoder` | `MKReverseGeocodingRequest` | iOS 18 (2024) | WWDC25 announced; CLGeocoder still works |
| Completion handler `MKLocalSearch.start` | `try await search.start()` | iOS 15 (2021) | Async/await native |

**Deprecated/outdated:**
- `@ObservableObject` + `@Published`: Phase 1 uses `@Observable` macro (Swift 5.9+). Do not introduce `@ObservableObject` anywhere in Phase 2.
- `UIPresentationController` for card expand: Not applicable — in-place animation is the decision.

---

## Open Questions

1. **MKLocalSearch result quality in target markets**
   - What we know: MKLocalSearch returns pizza places in general. Quality varies by market.
   - What's unclear: Whether "pizza" + `.restaurant` filter returns enough results in the target city (noted as Phase 2 risk in STATE.md).
   - Recommendation: First task in Phase 2 is a real-device smoke test. If results are poor, also try `naturalLanguageQuery: "pizza restaurant"` and `"pizzeria"`.

2. **MKLocalSearch result deduplication on region expand**
   - What we know: Expanding region and re-querying returns a new set of results that may overlap.
   - What's unclear: Whether Apple returns exactly the same items or slightly different sets on repeat queries.
   - Recommendation: Deduplicate by coordinate (within ~10m tolerance) or by name+city combination when merging batches.

3. **scrollPosition(id:) behavior during list refresh**
   - What we know: `scrollPosition(id:)` binding updates on both user and programmatic scrolls.
   - What's unclear: Whether setting `places = newPlaces` in PlacesService while a card is selected causes `scrollID` to become invalid and reset to nil.
   - Recommendation: After a place list refresh, programmatically scroll to the previously selected place's new index using `scrollPosition`'s `scrollTo(id:)` method.

4. **Haptic alignment debounce**
   - What we know: `.sensoryFeedback` fires every time `isAligned` changes. If pointing directly at target, the user is aligned continuously.
   - What's unclear: Whether the compass angle oscillates across the 5-degree threshold causing rapid re-fires.
   - Recommendation: Add a 2-second cooldown after alignment haptic fires. Track `lastHapticTime` in AppState.

---

## Sources

### Primary (HIGH confidence)
- Google Maps iOS URL Scheme — `developers.google.com/maps/documentation/urls/ios-urlscheme` — walking directions URL format
- Apple Maps URL Scheme — `developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/MapLinks/MapLinks.html` — `dirflg=w` walking parameter
- HackingWithSwift `scrollTargetBehavior` — `hackingwithswift.com/quick-start/swiftui/how-to-make-a-scrollview-snap-with-paging-or-between-child-views` — carousel snapping
- HackingWithSwift `sensoryFeedback` — `hackingwithswift.com/quick-start/swiftui/how-to-add-haptic-effects-using-sensory-feedback` — impact haptics
- HackingWithSwift NWPathMonitor — `hackingwithswift.com/example-code/networking/how-to-check-for-internet-connectivity-using-nwpathmonitor` — connectivity check
- HolySwift @Observable NWPathMonitor — `holyswift.app/how-to-monitor-network-in-swiftui/` — full Swift 6 implementation
- DeveloperMemos @AppStorage enum — `developermemos.com/posts/enums-appstorage-swiftui/` — enum storage pattern
- Livsy Code peek carousel — `livsycode.com/swiftui/paging-with-peek-three-ways-to-implement-paginated-scroll-in-swiftui/` — peek + scrollPosition tracking
- SerialCoder ScrollPosition — `serialcoder.dev/text-tutorials/swiftui/scrolling-programmatically-with-scrollposition-in-swiftui/` — programmatic scroll

### Secondary (MEDIUM confidence)
- NSHipster MKLocalSearch — `nshipster.com/mklocalsearch/` — confirmed: MKMapItem has name, phoneNumber, url, placemark only
- Polpiella searchable map — `polpiella.dev/mapkit-and-swiftui-searchable-map/` — confirmed: no sort, no rating/hours in mapItem
- WebSearch aggregate on MKLocalSearch pagination — multiple sources agree: ~10 results per request, no cursor/offset
- WWDC25 MapKit session — `developer.apple.com/videos/play/wwdc2025/204/` — confirmed: no rating/hours added in recent releases

### Tertiary (LOW confidence)
- WebSearch on MKLocalSearch result count "~10 by default" — single-source community claim, not from official docs
- Haptic debounce recommendation — inferred from sensoryFeedback behavior, not explicitly documented

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — confirmed Apple frameworks, no third-party deps
- MKLocalSearch API: MEDIUM — JS-blocked Apple docs, verified via 4+ community sources + NSHipster
- MKMapItem fields (no rating/hours): MEDIUM — consistent across all sources, WWDC25 confirms no addition
- Carousel pattern: HIGH — HackingWithSwift + Livsy both confirm scrollTargetBehavior approach
- Deep links: HIGH — fetched official Google Maps and Apple Maps URL scheme docs directly
- NWPathMonitor: HIGH — fetched complete code example from HolySwift, consistent with known API
- Pagination behavior: MEDIUM — ~10 result cap reported by community, not in official docs explicitly
- Haptic alignment: MEDIUM — sensoryFeedback API verified, trigger condition is design decision

**Research date:** 2026-02-21
**Valid until:** 2026-03-23 (30 days — stable Apple APIs)
