# Technology Stack

**Project:** Take Me to Pizza — Neobrutalist iOS Pizza Compass
**Researched:** 2026-02-21
**Research mode:** Ecosystem / Prescriptive

---

## Recommended Stack

### Core Platform

| Technology | Version / Target | Purpose | Why |
|------------|-----------------|---------|-----|
| Swift | 6.x (Xcode 16+) | Primary language | Native iOS, required by modern concurrency patterns |
| SwiftUI | iOS 17 minimum | All UI | Native, best animation support, @Observable fits reactive heading data |
| iOS Deployment Target | iOS 17.0 | Minimum supported | @Observable macro, CLLocationUpdate.liveUpdates(), ScrollTargetBehavior all require iOS 17. App Store currently requires building against iOS 18 SDK, but deployment target can be iOS 17. |
| Xcode | 16+ | Build toolchain | Required by App Store as of April 24, 2025 |

**Confidence: HIGH** — Apple Developer documentation confirms Xcode 16 + iOS 18 SDK is required for App Store submissions. iOS 17 as deployment target is the pragmatic floor given the features this app needs.

---

### Location and Compass

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Core Location (native) | iOS 17 API | Real-time compass heading and GPS coordinates | No third-party library needed; Apple's CLLocationManager.startUpdatingHeading() delivers CLHeading with trueHeading and magneticHeading. iOS 17 adds CLLocationUpdate.liveUpdates() as an AsyncSequence for GPS. |
| CLLocationManager | Built-in | Heading + GPS | Use @Observable wrapper pattern (see architecture note below) |
| CLLocationUpdate.liveUpdates() | iOS 17+ | GPS via async/await | Apple's modern alternative to the delegate pattern for location; introduced WWDC23 |

**Do not use:** SwiftLocation (github.com/malcommac/SwiftLocation, v6.0) — it wraps CLLocationManager with async/await, but for this app the native iOS 17 APIs do this natively. Adding a third-party dependency for something Apple now ships natively creates maintenance risk and adds binary size.

**Confidence: HIGH** — Verified via Apple Developer Documentation search results, WWDC23 CLLocationUpdate coverage, and multiple implementation tutorials.

Implementation pattern for heading:

```swift
@Observable
final class CompassViewModel: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var heading: Double = 0.0

    override init() {
        super.init()
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingHeading()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading
    }
}
```

Note: CLHeading.trueHeading requires location services to be running simultaneously. If location is off, only magneticHeading is populated. Always start both heading and location updates together.

---

### Places / Pizza Search API

**Recommendation: Apple MapKit (MKLocalSearch) as primary, with Google Places as fallback path if data quality proves insufficient.**

#### Primary: Apple MapKit — MKLocalSearch

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| MapKit / MKLocalSearch | iOS 17+ | Find nearby pizza restaurants | Free, no API key, no network cost, private (no data leaves Apple), integrates directly with Apple Maps for directions handoff |
| MKPointOfInterestFilter | iOS 13+ | Filter to restaurant category | MKPointOfInterestCategory.restaurant is a native category; combine with naturalLanguageQuery = "pizza" for specificity |
| MKLocalSearchCompleter | iOS 9.3+ | No rate limit, real-time query completion | For future search bar feature; has no rate limiting per Apple docs |

**Confidence: MEDIUM** — MKLocalSearch restaurant category confirmed via Apple documentation links. Data quality relative to Google Places is a known risk (see Pitfalls). Verified: MKPointOfInterestCategory.restaurant exists as a documented category.

Search request pattern:

```swift
func searchNearbyPizza(near coordinate: CLLocationCoordinate2D) async -> [MKMapItem] {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = "pizza"
    request.resultTypes = .pointOfInterest
    request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant, .foodMarket])
    request.region = MKCoordinateRegion(
        center: coordinate,
        latitudinalMeters: 5000,
        longitudinalMeters: 5000
    )

    let search = MKLocalSearch(request: request)
    guard let response = try? await search.start() else { return [] }
    return response.mapItems
}
```

MKLocalSearch.start() now has an async overload — no completion handler needed.

#### Fallback: Google Places SDK for iOS

| Technology | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| GooglePlaces (SPM) | 10.8.0 (released Jan 27, 2026) | Richer place data, more coverage | If MKLocalSearch data quality is insufficient (sparse results, bad ranking, missing places) |
| GooglePlacesSwift | Preview (bundled in 10.8.0 repo) | Swift-native API | Use instead of ObjC GooglePlaces if switching to Google |

**SPM URL:** `https://github.com/googlemaps/ios-places-sdk`
**iOS Minimum:** iOS 16 (per Google's docs)
**Requires:** Google Cloud Platform API key, billing account

**Google Places pricing (verified from official docs, current as of research date):**
- Nearby Search Pro SKU: basic fields (name, coordinates, photos)
- Nearby Search Enterprise SKU: ratings, phone numbers, opening hours
- Nearby Search Enterprise Plus SKU: reviews, dining options
- $200/month free credit; approximate cost ~$2.83 per 1,000 requests at basic tier

**Do not use both simultaneously.** Pick one API and commit. Mixing them creates data inconsistency when showing details.

**Confidence: HIGH for version/pricing** — Verified from official Google Maps Platform documentation and GitHub release notes (v10.8.0 Jan 27, 2026).

**Decision rationale:** Start with MapKit. It is free, requires no API key (no credential management, no App Store rejection risk for misconfiguration), and Apple Maps handles the directions handoff natively. Switch to Google Places only if user testing reveals that pizza result quality is unacceptably sparse in target markets.

---

### Apple Maps Directions Integration

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| MKMapItem.openInMaps() | iOS 3+ | Launch Apple Maps with walking/driving directions | Native one-liner, no additional setup; MKLaunchOptionsDirectionsModeKey controls mode |

```swift
mapItem.openInMaps(launchOptions: [
    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
])
```

**Confidence: HIGH** — Standard documented MapKit API, stable.

---

### UI and Animation

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| SwiftUI (native shapes + Canvas) | iOS 15+ | Pizza slice compass rendering | Custom Shape conformance with Path + arc drawing is the right tool; no library needed for a wedge/arc shape |
| SwiftUI .rotationEffect() | Native | Rotate compass needle to bearing | Pairs with .animation(.interpolatingSpring) for physical feel |
| .animation(.interpolatingSpring) | Native | Compass needle spring movement | interpolatingSpring produces the most natural "physical" compass needle snap; use stiffness ~170, damping ~26 for a well-damped compass feel |
| SwiftUI Canvas + TimelineView | iOS 15+ | High-performance redraws if needed | If rotationEffect triggers too many SwiftUI diffing passes under rapid heading changes, move to Canvas; usually unnecessary |

**Do not use Lottie** for the compass animation. The pizza slice needle rotation is driven by live data (heading changes many times per second). Lottie is designed for canned animations, not data-driven continuous rotation. Using Lottie here would require scrubbing its timeline to a heading value, which is a misuse of the library and adds 3MB+ binary overhead.

**Confidence: HIGH** — SwiftUI animation docs confirmed via Apple tutorials and developer blog posts. interpolatingSpring parameters confirmed via GetStream spring animation guide.

Compass rotation pattern:

```swift
struct CompassView: View {
    var bearingToPizza: Double  // degrees, 0 = north

    var body: some View {
        PizzaSliceShape()
            .rotationEffect(.degrees(bearingToPizza))
            .animation(.interpolatingSpring(stiffness: 170, damping: 26), value: bearingToPizza)
    }
}
```

---

### Horizontal Card Carousel

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| SwiftUI ScrollView (horizontal) + LazyHStack | iOS 17+ | Nearby spots carousel with batch loading | Native, no library. LazyHStack ensures off-screen cards are not rendered. |
| .scrollTargetBehavior(.viewAligned) | iOS 17+ | Snap-to-card behavior | Native paging API introduced iOS 17; cleaner than old .pagingEnabled workarounds |
| .scrollTargetLayout() | iOS 17+ | Marks which views are scroll targets | Pair with scrollTargetBehavior |
| onAppear / task modifier | Native | Trigger batch loading as user scrolls to last card | Standard infinite scroll trigger pattern |

**Do not use:** Third-party carousel libraries (Snap, etc.). iOS 17's scrollTargetBehavior covers this use case natively. Adding a library for a feature that the platform provides is unnecessary complexity.

**Confidence: HIGH** — ScrollTargetBehavior confirmed via Apple WWDC23 content and multiple 2024-2025 implementation guides.

```swift
ScrollView(.horizontal) {
    LazyHStack(spacing: 12) {
        ForEach(pizzaPlaces) { place in
            PlaceCard(place: place)
                .containerRelativeFrame(.horizontal, count: 1, spacing: 12)
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.viewAligned)
```

---

### State Management

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| @Observable macro (Observation framework) | iOS 17+ | ViewModels for location, places, compass | Replaces ObservableObject + @Published. Only re-renders views that read changed properties — critical for heading updates that arrive at high frequency |
| @State | Native | Local view state | Unchanged |
| @Environment | Native | Dependency injection of shared models | Pass @Observable objects via environment, not initializer |

**Do not use ObservableObject + @Published** for the compass ViewModel. With ObservableObject, any @Published property change triggers every observing view to re-render. With rapid heading updates (multiple per second), this creates unnecessary churn. @Observable tracks only the properties actually read by each view.

**Confidence: HIGH** — Verified via Apple migration guide and multiple performance comparison articles confirming iOS 17 @Observable's selective rendering.

---

### Design System (Neobrutalism)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| SwiftUI native views | Native | All UI components | No UI library; neobrutalism requires custom borders, shadows, and colors that component libraries actively fight against |
| Custom ViewModifiers | Native | .neobrutalistCard(), .neobrutalistButton() | Encapsulate the thick-border + offset-shadow pattern; apply consistently |
| SF Pro (system font) | Native | Primary typography | Use .fontWeight(.black) or .fontWeight(.heavy) for headlines; neobrutalism is bold-typography-first; system font avoids App Store review complications and loads instantly |

**Typography note:** Neobrutalism calls for bold, commanding type. SF Pro Black at large sizes with tight letter-spacing achieves the neobrutalist feel without requiring a custom font download. If a more "quirky" feel is needed for v2, consider adding a single custom display font (e.g., DM Sans or Space Grotesk via SPM or bundled), but defer this to a later phase.

**Core neobrutalist design tokens (implement as SwiftUI constants):**
- Border width: 3–4pt
- Shadow: Hard offset shadow, no blur, dark color (use `.shadow(color: .black, radius: 0, x: 4, y: 4)`)
- Colors: High-saturation primaries; for Take Me to Pizza, pizza colors — red, orange, cream/yellow
- Corner radius: 0–4pt (flat or very slightly rounded)

**Confidence: MEDIUM** — Based on neobrutalism design principles from NN/G and design community resources; SwiftUI implementation approach is well-established but specific token values require design iteration.

---

### Dependency Management

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift Package Manager (SPM) | Native in Xcode 16 | All third-party dependencies | Native to Xcode; CocoaPods is entering maintenance mode (Google confirmed this August 2025); SPM is the current standard |

**Do not use CocoaPods.** Google deprecated it for their iOS SDKs in August 2025. Any new project in 2026 should be SPM-first.

**Confidence: HIGH** — Google's own release notes confirm CocoaPods entered maintenance mode August 18, 2025.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Places API | MapKit MKLocalSearch | Google Places SDK | Free vs. paid; no API key complexity; directions handoff is native. Upgrade to Google if data quality fails. |
| Places API | MapKit MKLocalSearch | Foursquare Places API | Less iOS-native; adds another paid API key; no advantage over Google for this use case |
| State management | @Observable | ObservableObject | @Observable has selective property tracking, critical for high-frequency heading updates |
| Animation | SwiftUI native | Lottie | Lottie is for canned animations, not live data-driven rotation |
| Carousel | Native ScrollView | SnapKit / Snap carousel library | iOS 17 scrollTargetBehavior covers this natively; no library needed |
| Dependency manager | SPM | CocoaPods | CocoaPods in maintenance mode; SPM is current standard |
| Location async | Native CLLocationUpdate | SwiftLocation (v6.0) | CLLocationUpdate.liveUpdates() in iOS 17 does the same thing natively |
| Custom fonts | SF Pro (system) | Bundled custom font | System font loads instantly, no App Review complications; achieves neobrutalist boldness with .fontWeight(.black) |

---

## Full Dependency List

This app can be built with **zero third-party dependencies** using only Apple frameworks:

- **Core Location** — heading, GPS
- **MapKit** — place search, map items, directions handoff
- **SwiftUI** — all UI, animation, layout
- **Foundation** — data handling

**If Google Places becomes necessary (escalation path):**

Add via SPM:
```
Repository: https://github.com/googlemaps/ios-places-sdk
Version: 10.8.0 (exact)
Product: GooglePlaces
```

---

## Sources

**Apple Official (HIGH confidence):**
- Apple Developer: App Store upcoming requirements (SDK requirement = iOS 18, Xcode 16)
- Apple Developer: MKPointOfInterestCategory.restaurant documentation
- Apple Developer: MKLocalSearch documentation
- Apple Developer: CLLocationManager.startUpdatingHeading()
- Apple Developer: @Observable migration guide

**Google Official (HIGH confidence):**
- Google Places SDK for iOS release notes: v10.8.0, January 27, 2026
- Google Places SDK GitHub: https://github.com/googlemaps/ios-places-sdk
- Google: CocoaPods maintenance mode announcement, August 2025
- Google: Places SDK iOS pricing tiers (Pro/Enterprise/Enterprise Plus SKUs)

**Community / MEDIUM confidence:**
- WWDC23 coverage of CLLocationUpdate.liveUpdates()
- GetStream SwiftUI spring animations guide (interpolatingSpring parameters)
- iOS 17 scrollTargetBehavior implementation articles (multiple, consistent)
- @Observable performance comparison articles (multiple, consistent)
- NN/G Neobrutalism definition and best practices
