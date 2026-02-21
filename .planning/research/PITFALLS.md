# Domain Pitfalls: SouthYeast

**Domain:** iOS real-time compass + location services + places API
**Researched:** 2026-02-21
**Confidence:** HIGH for compass/location mechanics (verified against Apple docs and community); MEDIUM for places API cost patterns (pricing changed March 2025)

---

## Critical Pitfalls

Mistakes that cause rewrites, App Store rejection, or the compass being fundamentally broken.

---

### Pitfall 1: The 0/360 Degree Wrap — Compass Spins Full Circle Through North

**What goes wrong:**
When the bearing to the pizza changes from, say, 359 degrees to 1 degree, SwiftUI's `withAnimation` interpolates through the short path numerically. But 359 and 1 are numerically far apart, so the animation rotates the pizza slice backward through 358 degrees instead of forward through 2 degrees. The slice spins almost a full revolution every time the user turns and crosses north.

**Why it happens:**
SwiftUI animates angle values as raw `Double` — it does not automatically detect "these two angles represent nearly the same direction." `rotationEffect` with `.degrees(1.0)` and `.degrees(359.0)` are treated as far apart because they are, numerically. There is no built-in shortest-arc interpolation.

**Consequences:**
The compass is unwatchable near north. The pizza slice randomly thrashes. This is the single most visible polish failure for a compass app.

**Prevention:**
Track heading as a monotonically-accumulating value, not a normalized 0-360 value. When a new heading arrives, calculate the angular delta using modular arithmetic, then add that delta to the accumulated value. Never set the rotation target to a raw CLHeading degree.

```swift
// Pseudocode pattern
func updateRotation(newHeading: Double) {
    var delta = newHeading - previousHeading
    // Normalize delta to [-180, 180]
    if delta > 180 { delta -= 360 }
    if delta < -180 { delta += 360 }
    accumulatedRotation += delta
    previousHeading = newHeading
    // Animate using accumulatedRotation
}
```

Alternatively: use `CABasicAnimation` with `byValue` (relative rotation) instead of `toValue` (absolute), which lets Core Animation take the shortest path naturally.

**Detection (warning signs):**
- Compass spins wildly when heading past due north
- Unit test: animate from 350 to 10 degrees — the pizza should rotate 20 degrees forward, not 340 degrees backward

**Phase to address:** Compass animation phase (Phase 1 or whichever builds the rotating slice). Address before any other animation polish work.

---

### Pitfall 2: Bearing Formula Applied Without Subtracting Device Heading

**What goes wrong:**
The bearing from user coordinates to pizza coordinates is calculated correctly in geographic terms (degrees from true/magnetic north). But it's applied directly as the pizza slice rotation angle. The slice points to where the pizza is on a map — not where the user needs to look. A user facing east who calculates a pizza bearing of 90 degrees will see the slice point right (east) — correct. But if they turn to face south, the bearing is still 90 degrees and the slice still points east instead of rotating to their left.

**Why it happens:**
Bearing from point A to point B is a fixed geographic direction. The device heading is what direction the device faces. The on-screen rotation must be: `bearing - deviceHeading`. Forgetting to subtract the current heading is extremely common in first implementations.

**Consequences:**
The compass points at a fixed map direction, not at the pizza from the user's perspective. It looks broken to anyone who rotates the phone.

**Prevention:**
The rotation angle for the pizza slice is always relative:
```
sliceRotation = bearingToTarget - deviceCurrentHeading
```
Both values must use the same north reference (magnetic or true). Use `trueHeading` for both if location services are active and the device has GPS fix; fall back to `magneticHeading` otherwise. Never mix them.

**Detection (warning signs):**
- Spinning the phone in place — the slice should stay pointed at the pizza (it barely moves). If it rotates with the phone, the formula is missing `- deviceHeading`
- If the slice stays fixed to the screen regardless of phone rotation, heading is not being subtracted

**Phase to address:** Compass core logic phase, before any UI animation work.

---

### Pitfall 3: Ignoring `headingAccuracy` — Displaying Garbage Compass Readings

**What goes wrong:**
`CLHeading.headingAccuracy` returns a negative value when the heading is invalid. Typical scenario: app launches indoors near steel/concrete, magnetometer is not yet calibrated, `headingAccuracy` is `-1.0`. The pizza slice confidently points in a random direction because the code reads `magneticHeading` without checking accuracy first.

**Why it happens:**
The `headingAccuracy` property is not prominently documented in most tutorials. Developers read `magneticHeading` (which is a Double and always has a value) without realizing a negative accuracy means "do not trust this reading."

**Consequences:**
On first launch indoors, the compass points at garbage. Users think the app is broken and close it. This is especially damaging for an app whose entire value proposition is compass accuracy.

**Prevention:**
Always gate heading display on `headingAccuracy`:
- `< 0`: invalid — show an uncalibrated state indicator, do not rotate the slice
- `0...15`: good — full confidence display
- `15...30`: fair — display with minor visual uncertainty treatment
- `> 30`: poor — consider showing a "move away from interference" nudge

Implement `locationManagerShouldDisplayHeadingCalibration(_:)` and return `true` to let iOS show the calibration figure-eight prompt when accuracy is poor. Do not suppress this.

**Detection (warning signs):**
- Compass wildly off indoors
- No calibration prompt ever appears
- `headingAccuracy` log shows -1 or very high values at launch

**Phase to address:** Compass core logic phase. The calibration gate must ship with the first compass build.

---

### Pitfall 4: Location Permission Rejected With No Recovery Path

**What goes wrong:**
iOS location permission is a one-shot prompt. If the user taps "Don't Allow," the app can never request again. The app shows a blank screen or crashes because the code assumes location will always be available.

**Why it happens:**
Apps that prompt for location at launch before establishing any context see significantly higher rejection rates. Once denied, `CLAuthorizationStatus.denied` is permanent until the user manually goes to Settings. Apps that don't handle `denied` and `restricted` states gracefully are left in an undefined state.

**Consequences:**
- App Store rejection risk: Apple requires apps to work or gracefully degrade when permissions are denied
- User abandonment: no clear recovery path means the user just deletes the app
- Crash risk if location code assumes non-nil location

**Prevention:**
Handle all five authorization states explicitly:
- `.notDetermined`: wait for prompt, do not show compass
- `.authorizedWhenInUse`: nominal path
- `.authorizedAlways`: nominal path (not needed for this app, do not request)
- `.denied`: show permission-denied screen with deep-link button to `UIApplication.openSettingsURLString`
- `.restricted`: show parental controls message, no settings button (user cannot change it)

Write the permission prompt reason string (`NSLocationWhenInUseUsageDescription`) in plain language explaining the pizza compass — not generic boilerplate. Example: "SouthYeast uses your location to find the nearest pizza and point you to it. Without location, the compass cannot work."

Do NOT request `.authorizedAlways` — this app only needs foreground location. Requesting "Always" triggers a more aggressive review and increases rejection rate.

**Detection (warning signs):**
- Permission prompt appears immediately on cold launch with no context
- No UI state for the `denied` case
- Settings deep-link button is absent from the denied state screen

**Phase to address:** Location permission handling must be Phase 1 infrastructure. It gates everything else.

---

### Pitfall 5: Privacy Manifest Missing — App Store Rejection

**What goes wrong:**
Since May 1, 2024, Apple requires a `PrivacyInfo.xcprivacy` file in every new App Store submission that uses required reason APIs. Core Location is a required reason API. Missing or incomplete privacy manifest causes App Store review rejection. Apple rejected approximately 12% of submissions in Q1 2025 for privacy manifest violations.

**Why it happens:**
Many tutorials and starter templates predate the May 2024 requirement. Developers build a working app, then fail at submission with a confusing rejection message about privacy manifests.

**Consequences:**
Hard stop at App Store submission. Not a crash bug — a shipping blocker. Requires creating and validating the manifest before resubmitting.

**Prevention:**
Add `PrivacyInfo.xcprivacy` to the project from the beginning. Declare:
- Location data collection and its purpose (app functionality, not tracking)
- Whether data is linked to the user identity (should be: no, for this app)
- Any third-party SDKs (Google Places SDK also needs its own manifest entry)

The Google Places SDK for iOS (as a third-party SDK with data access) requires a corresponding entry in the app's privacy manifest.

**Detection (warning signs):**
- No `PrivacyInfo.xcprivacy` file in the Xcode project
- App Store Connect validation warnings during archive upload
- Rejection email mentioning "required reason APIs"

**Phase to address:** App Store submission preparation phase, but scaffold the file during initial project setup.

---

## Moderate Pitfalls

Mistakes that create technical debt, user frustration, or significant rework.

---

### Pitfall 6: Excessive Battery Drain from Continuous Location + Heading Updates

**What goes wrong:**
`startUpdatingLocation()` and `startUpdatingHeading()` both default to maximum accuracy and continuous updates. Left running at full power, the app burns battery noticeably faster than expected — especially if the screen stays on (which it likely does for a compass app in active use).

**Why it happens:**
The default `desiredAccuracy` is `kCLLocationAccuracyBest`, which activates GPS hardware. For a pizza-finding compass, GPS-level accuracy within 3 meters is overkill — the user needs to know which block the pizza place is on, not its exact GPS position.

**Prevention:**
- Set `desiredAccuracy` to `kCLLocationAccuracyNearestTenMeters` or even `kCLLocationAccuracyHundredMeters` for the initial Places search
- Heading updates are separate from location updates and cannot be throttled by accuracy, but can be filtered by `headingFilter` (minimum degrees change before callback fires — default is 1 degree; set to 3-5 degrees to reduce update frequency)
- Stop `startUpdatingLocation()` after getting a sufficient fix for the initial search; restart only when the user's position changes enough to invalidate the current results (use `distanceFilter`)
- Set `distanceFilter` to 50-100 meters so location callbacks only fire when the user has meaningfully moved

**Detection (warning signs):**
- Battery instruments in Xcode show continuous GPS spike
- `desiredAccuracy` left at default
- `distanceFilter` is `kCLDistanceFilterNone` (fires on every meter of movement)
- No `stopUpdatingLocation()` call after initial fix

**Phase to address:** Location infrastructure phase. Performance profiling in a dedicated testing pass before beta.

---

### Pitfall 7: Places API Costs Spiraling Due to Unbounded Queries

**What goes wrong:**
Google Places Nearby Search is billed per call, with additional charges based on which data fields are requested. Two failure modes: (1) calling Nearby Search every time the location updates (continuous queries), (2) requesting all place fields instead of field-masking to only what is needed.

Google restructured pricing on March 1, 2025: the old $200/month credit is gone, replaced by free usage thresholds per SKU (Essentials tier: 10,000 events/month free). For a small app this should be fine, but unbounded queries can exceed it.

**Prevention:**
- Cache search results. Only re-query when the user has moved significantly (50-100+ meters from the last search origin) or after a reasonable time window
- Use field masking: only request the fields you display (name, location coordinates, business_status, opening hours if showing open/closed). Do not request photos, reviews, or atmosphere fields unless needed — these escalate to higher billing SKUs
- The carousel loads 10 at a time. This is already good. Ensure "load more" is user-triggered, not automatic
- For the Places SDK for iOS, use `GMSPlaceProperty` to specify only the fields needed
- `maxResultCount` is capped at 20 per request — design the infinite scroll around this constraint

**Detection (warning signs):**
- Nearby Search called inside `locationManager(_:didUpdateLocations:)` directly
- All `GMSPlaceProperty` values requested instead of a specific subset
- No result cache between location updates
- Google Cloud Console showing unexpectedly high request volume

**Phase to address:** Places API integration phase. Cache and field masking must be designed upfront, not bolted on after billing surprises.

---

### Pitfall 8: Heading Jitter — Noisy Magnetometer Makes Compass Twitch

**What goes wrong:**
Even with `CLHeading` (which applies internal filtering superior to raw `CMMagnetometerData`), the heading value updates frequently with small variations due to magnetometer noise. Without smoothing, the pizza slice twitches and trembles even when the phone is held still, looking broken and unpolished.

**Why it happens:**
The magnetometer is sensitive hardware. Small electrical variations, nearby metal objects, and even holding the phone slightly differently all produce heading noise of 1-5 degrees that is below the `headingFilter` threshold but still causes visible animation jitter when applied directly.

**Prevention:**
Apply a low-pass filter to the heading before driving the animation:
```swift
// filterFactor ~0.1 = responsive, ~0.3 = smoother but laggier
filteredHeading = filterFactor * filteredHeading + (1 - filterFactor) * newRawHeading
```

Tune `filterFactor` empirically. Too high (0.8+) makes the compass feel sluggish. Too low (0.05) barely filters. For a pizza compass — where the user is walking, not doing precision navigation — 0.1-0.2 provides a good balance.

Additionally: set `CLLocationManager.headingFilter` to `3.0` (degrees) to prevent callbacks from firing on sub-3-degree changes. This is the first line of noise reduction before the low-pass filter.

**Detection (warning signs):**
- Compass slice visibly trembles when phone is held perfectly still
- Heading values logged show rapid 1-3 degree oscillations
- No `headingFilter` set (remains at default of `kCLHeadingFilterNone` or 1 degree)

**Phase to address:** Compass animation polish phase. Set `headingFilter` in the core location phase; add low-pass filter during animation polish.

---

### Pitfall 9: magneticHeading vs trueHeading Mismatch With Bearing Calculation

**What goes wrong:**
The bearing formula from user coordinates to pizza coordinates returns degrees from true north (geographic north). Using `magneticHeading` for the device heading (which is relative to magnetic north) introduces a systematic error equal to the local magnetic declination — which varies from -20 to +20 degrees depending on geographic location. In Seattle this is approximately 15 degrees east. A user in Seattle with `magneticHeading` and a `trueHeading`-based bearing will have a pizza slice consistently pointing 15 degrees in the wrong direction.

**Why it happens:**
`magneticHeading` is the default and simpler to access. `trueHeading` requires that location services are active and the device has a GPS fix. Developers use `magneticHeading` without realizing the bearing formula implicitly assumes true north.

**Prevention:**
Use `trueHeading` for the device heading when computing the relative bearing. Check that `trueHeading >= 0` (negative indicates location services are not active, making true heading unavailable). Fall back to `magneticHeading` with a developer warning if `trueHeading` is negative.

Also: `trueHeading` in `CLHeading` requires that location updates are also running. Starting heading updates alone is insufficient — `startUpdatingLocation()` must also be called, or `trueHeading` will remain -1.

**Detection (warning signs):**
- Compass always points slightly wrong in the same direction in a given city
- Error is consistent rather than random (suggests declination offset, not noise)
- `CLHeading.trueHeading` logged as -1.0

**Phase to address:** Compass core logic phase.

---

### Pitfall 10: No State Machine for Location — Race Conditions at Launch

**What goes wrong:**
On first launch, the sequence is: request permission → wait for authorization callback → start location updates → wait for first location fix → query Places API → display compass. Without explicit state management, developers sprinkle `if locationManager.location != nil` guards everywhere and produce subtle race conditions: the compass tries to calculate a bearing before a location exists, the Places query fires before authorization is granted, heading updates start before location updates.

**Why it happens:**
Core Location has multiple asynchronous callbacks that can arrive in any order. `locationManagerDidChangeAuthorization` fires immediately if permission is already granted (from a previous session), which can cause double-initialization if not handled as a state transition.

**Prevention:**
Model location state explicitly:
```
States: notDetermined → requesting → denied/restricted → locating → located → searching → ready
```

All compass and Places API code only runs from `located` state onward. Use a single `CLLocationManager` instance (never create multiple). Do not initialize a new `CLLocationManager` each time the view appears — create it once and observe its delegate across the app lifecycle.

**Detection (warning signs):**
- Force-unwraps of `locationManager.location!`
- Places search triggered in `viewDidLoad` before authorization check
- Multiple `CLLocationManager` instances created
- Location updates called before checking authorization status

**Phase to address:** Location infrastructure phase. State machine design before any feature implementation.

---

## Minor Pitfalls

Problems that cause confusion or polish issues but are recoverable.

---

### Pitfall 11: Empty Results — No Pizza Near the User

**What goes wrong:**
Google Nearby Search for `pizza_restaurant` within a given radius returns zero results. Common in rural areas, industrial zones, airports, suburbs outside typical delivery areas. App shows blank carousel and a compass pointing nowhere (or at the wrong cached target).

**Prevention:**
- Design explicit empty state UI from day one — not an afterthought
- Implement radius expansion: if 0 results at 1km, retry at 3km, then 5km
- Display the expanded radius to the user: "Nearest pizza is 4.2 km away"
- If truly nothing within 50km, show a good-natured empty state consistent with the app's personality (this is a fun app — treat edge cases with humor, not error messages)
- Never leave the compass pointing at the previous pizza place's cached coordinates

**Detection (warning signs):**
- No empty state UI exists in the design
- Radius is hardcoded with no fallback logic
- Compass still shows a direction after all results are cleared

**Phase to address:** Places API integration phase. Plan empty state handling before building the happy path.

---

### Pitfall 12: Heading Updates Stopped When App Goes to Background

**What goes wrong:**
`startUpdatingHeading()` and `startUpdatingLocation()` stop delivering callbacks when the app is backgrounded (without background location mode enabled). If the user locks their phone and reopens the app, the compass displays stale heading data until a new callback fires, which can take several seconds.

**Why it happens:**
This is correct iOS behavior — but developers expect the compass to immediately show the current heading on return to foreground, not a stale cached value.

**Prevention:**
- On `applicationWillEnterForeground`, invalidate the displayed heading (show uncalibrated state) until the first new `didUpdateHeading` callback arrives
- The heading updates resume quickly after returning to foreground — the gap is small but the stale display needs to be masked, not shown

**Detection (warning signs):**
- After backgrounding and returning, compass briefly shows wrong direction
- No foreground transition handling in the location manager observer

**Phase to address:** App lifecycle integration phase.

---

### Pitfall 13: Single `CLLocationManager` vs Multiple Instances

**What goes wrong:**
Creating a new `CLLocationManager` in each SwiftUI view that needs location (or each time a view appears) creates multiple parallel location sessions. iOS attempts to satisfy all of them but the behavior is unpredictable. More critically: each instance's delegate fires independently, causing duplicate callbacks, duplicate Places queries, and heading updates arriving twice.

**Prevention:**
Use a single `CLLocationManager` instance as an `ObservableObject` (or actor) injected via SwiftUI's environment. All views observe the same source of truth.

**Detection (warning signs):**
- `CLLocationManager()` called inside `View.body` or `View.onAppear`
- Multiple `didUpdateHeading` callbacks arriving within the same millisecond with identical values

**Phase to address:** Architecture/location infrastructure phase.

---

### Pitfall 14: Neobrutalist UI Breaking Accessibility

**What goes wrong:**
Neobrutalist design uses high contrast, thick borders, and bold typography — which is actually good for accessibility. But the rotating pizza slice has no accessible label or announcement. VoiceOver will announce "Image" and say nothing about compass direction. Dynamic Type may break the bold neobrutalist typography if system font sizes override custom fonts.

**Prevention:**
- Add `accessibilityLabel` to the compass with the current bearing direction ("Pointing northeast, 2.3 km to Joe's Pizza")
- Use `accessibilityValue` to update dynamically as heading changes
- Test with VoiceOver and Dynamic Type large accessibility sizes before App Store submission

**Phase to address:** Accessibility and polish phase.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Compass core rotation logic | Heading wrap bug (0/360) | Track accumulated rotation, not normalized degrees |
| Bearing-to-target calculation | Missing device heading subtraction | Always compute `bearing - deviceHeading` |
| Location permission flow | One-shot prompt with no recovery | Handle all 5 `CLAuthorizationStatus` states |
| Heading accuracy display | Showing garbage when `headingAccuracy < 0` | Gate display on accuracy; show calibration prompt |
| Battery performance | Full-accuracy continuous updates | Set `distanceFilter`, `headingFilter`, reduce `desiredAccuracy` |
| Places API integration | Unbounded queries + no field masking | Cache results, only re-query on significant movement |
| Places API integration | Empty results with no fallback | Implement radius expansion + empty state UI |
| Heading smoothness | Raw heading jitter on still phone | Low-pass filter + `headingFilter` of 3 degrees |
| north reference confusion | `magneticHeading` vs `trueHeading` mismatch | Use `trueHeading`; require location updates to be active |
| App Store submission | Missing `PrivacyInfo.xcprivacy` | Create privacy manifest at project setup, not submission |
| SwiftUI architecture | Multiple `CLLocationManager` instances | Single instance as injected `ObservableObject` |
| Launch sequence | Race conditions before location fix | Explicit state machine before any location-dependent code |

---

## Sources

- [Apple Energy Efficiency Guide — Location Best Practices](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/LocationBestPractices.html)
- [CLHeading — Apple Developer Documentation](https://developer.apple.com/documentation/corelocation/clheading)
- [CLAuthorizationStatus.denied — Apple Developer Documentation](https://developer.apple.com/documentation/corelocation/clauthorizationstatus/denied)
- [Requesting Authorization to Use Location Services — Apple Developer Documentation](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)
- [Nearby Search (New) — Places SDK for iOS](https://developers.google.com/maps/documentation/places/ios-sdk/nearby-search)
- [Places SDK for iOS Usage and Billing](https://developers.google.com/maps/documentation/places/ios-sdk/usage-and-billing)
- [Privacy Manifest Files — Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Adding a Privacy Manifest to Your App](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
- [trueHeading — Apple Developer Documentation](https://developer.apple.com/documentation/corelocation/clheading/1423568-trueheading)
- [Taking Control of Rotation Animations in iOS — BiTE Interactive](https://www.biteinteractive.com/taking-control-of-rotation-animations-in-ios/)
- [Low-Pass Filter Implementation Gist](https://gist.github.com/kristopherjohnson/0b0442c9b261f44cf19a)
- [How to Build a Compass App in Swift — Five Stars](https://www.fivestars.blog/articles/build-compass-app-swift/)
- [Location Authorization Best Practices with Combine — Medium](https://medium.com/@ashidiqidimas/location-authorization-best-practices-and-how-to-build-it-reactively-using-combine-b220aa3bfa2c)
- [Deep Dive into iOS Location Permission — Notificare](https://notificare.com/blog/2023/05/19/deep-dive-into-ios-location-permission/)
