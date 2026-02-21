# Feature Landscape: SouthYeast

**Domain:** Location-based single-purpose food finder / novelty compass iOS app
**Researched:** 2026-02-21

---

## Framing: What Kind of App Is This?

SouthYeast is not Yelp. It is not Google Maps. It is a novelty instrument app with a restaurant discovery side-effect.

This distinction matters enormously for feature categorization. Table stakes for Yelp (saved lists, reviews, reservations) are anti-features for SouthYeast. The closest analogs are:

- **Pizza Compass** (grandideastudio.com) — hardware device that points to nearest pizza. Proof the concept works and users love the gag.
- **FoodCompass** (App Store, 2021) — selects food type, points to nearest. Similar core mechanic, less personality.
- **HapticNav** — compass with haptic corridors. Shows how tactile feedback elevates a simple compass experience.

The table stakes for SouthYeast are the minimum that makes the core joke land, not the minimum to compete with Yelp.

---

## Table Stakes

Features users expect. Missing = the app feels broken or untrustworthy.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Location permission priming | iOS requires it; users distrust apps that demand location without explanation | Low | Custom pre-dialog before system prompt; explain the gag, then ask |
| Compass that actually points correctly | The entire premise. Wrong = trust destroyed immediately | Medium | CLLocationManager heading + correct bearing math (magnetic vs true north) |
| Real pizza places, not stale data | Users will check if the place is real. Fake or closed results kill the joke | Medium | Google Places API or Apple MapKit — must include `openNow` or hours data |
| Distance shown on cards | Users need to know if "nearest" is 0.2 miles or 12 miles | Low | Calculated from user location to place coordinate |
| Smooth compass rotation | Jittery/jumpy compass feels broken, not playful. Animation is load-bearing | Medium | Heading updates need smoothing (interpolation, not raw jumps); SwiftUI rotation animation |
| Cards show name and distance | Minimum viable identification for a place | Low | Name + distance label on carousel card |
| Tap card → expanded details | Where is this place? Is it open? | Low | Address, hours (open/closed status), rating, phone |
| Tap for Apple Maps directions | Users who commit to going need actual navigation | Low | `MKMapItem.openInMaps()` is trivial; the feature is expected |
| Graceful empty state | What if you're in the middle of nowhere? Or GPS fails? | Low | Clear error message; don't spin forever |
| Location unavailable handling | User denies permission, or GPS is off | Low | Deep link to Settings; friendly explanation |

---

## Differentiators

Features that make SouthYeast SouthYeast. Not expected by users, but create delight and define the product's personality.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Pizza slice compass needle | The central gag. A pizza slice as a compass needle is the whole bit | Medium | Custom SwiftUI shape or image; must feel physical and satisfying |
| Mystery mode | The app's personality in one feature. Trust the slice, don't look at the name | Low-Med | Single card at far-left of carousel; toggled by tapping it; hides names throughout |
| Neobrutalist visual design | Aesthetic cohesion makes it feel intentional, not cheap | Medium | Thick outlines, bold type, high contrast, slightly raw. Cannot be half-done. |
| Haptic feedback on compass | Makes the compass feel like a physical instrument; tactile confirmation when pointing at target | Low-Med | UIImpactFeedbackGenerator + CoreHaptics; pulse when aligned with nearest pizza |
| "Getting warm" proximity signal | When you walk toward the pizza, something should acknowledge it | Medium | Distance delta calculation; subtle haptic or visual change as distance shrinks |
| Polished micro-animations | Carousel card spring animations, compass snap, card expand/collapse. Polish IS the product. | Medium | SwiftUI spring physics; timing matters here |
| Infinite scroll (batch load 10) | Makes it feel like there's always more pizza nearby | Low-Med | Pagination on Places API query; trigger load near end of list |
| Onboarding that explains the gag | Users who don't get the joke within 5 seconds won't stay | Low | 2-3 screens max. Show the compass, explain mystery mode, done. |

---

## Anti-Features

Things to deliberately NOT build. These seem helpful but violate the core value proposition or introduce bloat that kills the project.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| User accounts / login | No one opens a pizza compass app and thinks "I should sign in." Adds friction to a zero-friction experience. | Stay fully anonymous; no persistence across devices needed |
| Saved / favorites list | Contradicts the ephemeral "trust the slice" philosophy. Also requires persistence infrastructure. | Let mystery mode fill this emotional role: you don't need to save, you just go |
| In-app reviews or ratings | Yelp already exists. Adding reviews means maintaining content moderation, which is a full-time job. | Surface third-party ratings from the API (read-only) |
| Cuisine filtering beyond pizza | Scope creep that dilutes the joke. A pizza compass that also finds tacos is just a food compass. | Stay pizza-only for v1. If the concept works, a sequel "SouthBurger" can exist. |
| Social features / sharing | "Share to Instagram" sounds fun but requires auth, deep links, image generation, and ongoing maintenance. | The word-of-mouth moment is someone showing their phone to a friend. That's free. |
| In-app ordering | Not a delivery app. The compass points; you walk. | Apple Maps handoff is the right exit point |
| Offline mode / caching | Compass apps need live GPS. Cached pizza data stales quickly (hours, closed status). | Require connectivity; show a friendly state if offline |
| Push notifications | "Pizza nearby!" is spam. This app has no recurring engagement loop that benefits from notifications. | Open the app when you want pizza. That's the entire UX. |
| Dark mode | Neobrutalism is high-contrast by design. A dark mode variant would require duplicate design work and likely look bad. | Define one deliberate palette and own it |
| Onboarding that asks preferences | The app has no preferences to collect. No filters, no accounts, no personalization engine. | Skip the quiz. Show the compass. Start pointing. |
| Map view of nearby restaurants | The compass IS the directional interface. A list-plus-map duplicates what Apple Maps already does better. | Carousel cards handle discovery; Apple Maps handles navigation |

---

## Feature Dependencies

```
Location Permission Granted
    └── GPS Position Available
            ├── Nearest Place Calculated
            │       ├── Compass Bearing Computed
            │       │       └── Pizza Slice Rotates (compass UI)
            │       │               └── Haptic Pulse (when aligned)
            │       └── Distance Shown on Card
            ├── Carousel Populated (10 places, sorted by distance)
            │       ├── Card Tap → Expanded Details
            │       │       └── "Get Directions" → Apple Maps
            │       └── Near-end of list → Load 10 More (infinite scroll)
            └── Mystery Mode (hides names in carousel, not compass)
```

Key dependency notes:

- **Everything depends on location permission.** Onboarding must establish why location is needed before the system dialog fires.
- **Compass accuracy depends on device heading.** On iPhone, this is `CLLocationManager` heading (uses magnetometer). Must request heading updates separately from position updates.
- **Infinite scroll depends on Places API pagination.** Google Places API (New) uses a `pageToken`; Apple MapKit JS and native MKLocalSearch handle this differently. Batch size of 10 is correct for cost management.
- **Mystery mode is a display-only toggle.** It does not change what data is fetched. Implement as a UI state flag, not a separate data path.
- **Haptic pulse on alignment** depends on heading accuracy. Do not fire haptics when `CLHeading.headingAccuracy` is poor (> 20 degrees).

---

## MVP Recommendation

The core product already described in PROJECT.md is well-scoped. Prioritize in this order:

**Must ship for MVP:**
1. Location permission + priming screen
2. Nearest pizza place found and compass pointing at it
3. Pizza slice needle rotating correctly
4. Carousel with cards (name, distance)
5. Card expand (hours, address, rating)
6. Apple Maps handoff
7. Empty / error states

**Ship alongside MVP (high personality value, low cost):**
8. Mystery mode (single leftmost card, display flag only)
9. Haptic pulse on compass alignment
10. Smooth compass animation (non-negotiable for feel)

**Defer until post-MVP validation:**
- Infinite scroll: Works without it if you load 20 results upfront. Add pagination only if users report wanting more.
- Onboarding flow: Functional app first; add onboarding if early users don't understand mystery mode.
- "Getting warm" proximity signal: Nice polish, but requires distance delta tracking — add in v1.1.

---

## Competitive Context

Apps in this exact space:

| App | Core Mechanic | What SouthYeast Does Better |
|-----|--------------|----------------------------|
| Pizza Compass (hardware) | Points to pizza, open/closed bar | Software, always-on phone, mystery mode, better data |
| FoodCompass (App Store) | Food type → nearest | Pizza-only focus, stronger personality, neobrutalist design |
| Yelp Nearby | List + map, heavy filters | Zero friction, one-tap purpose, no account needed |
| Google Maps Nearby | Full-featured discovery | Novelty, speed, the joke itself |

The competitive moat is not features — it is the **quality of the gag**. A pizza slice that spins correctly, with good haptics, in a bold visual style, with mystery mode as a punchline, is more differentiated than any feature list comparison suggests.

---

## Sources

- [Key Features for Building an Effective Restaurant Search App - AppInventiv](https://appinventiv.com/blog/restaurant-finding-app-features/)
- [Pizza Compass - Grand Idea Studio](https://grandideastudio.com/portfolio/other/pizza-compass/)
- [Pizza Compass - App Store](https://apps.apple.com/us/app/pizza-compass/id642652985)
- [FoodCompass - App Store](https://apps.apple.com/us/app/foodcompass-find-food-easily/id1602104052)
- [Getting heading and course information - Apple Developer Documentation](https://developer.apple.com/documentation/corelocation/getting-heading-and-course-information)
- [Haptic Feedback in iOS: A Comprehensive Guide - Medium](https://medium.com/@mi9nxi/haptic-feedback-in-ios-a-comprehensive-guide-6c491a5f22cb)
- [Mobile Permission Requests: Timing, Strategy & Compliance - Dogtown Media](https://www.dogtownmedia.com/the-ask-when-and-how-to-request-mobile-app-permissions-camera-location-contacts/)
- [Carousels on Mobile Devices - Nielsen Norman Group](https://www.nngroup.com/articles/mobile-carousels/)
- [Yelp Fall Product Release 2025](https://blog.yelp.com/news/fall-product-release-2025/)
- [Google Places API - Place Data Fields](https://developers.google.com/maps/documentation/places/web-service/data-fields)
- [8 Best Restaurant Finder Apps in 2026 - FixThePhoto](https://fixthephoto.com/best-restaurant-finder-apps.html)
