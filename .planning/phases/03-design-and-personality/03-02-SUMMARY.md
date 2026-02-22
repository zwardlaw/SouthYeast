---
phase: 03-design-and-personality
plan: 02
subsystem: ui
tags: [swiftui, neobrutalist, design-system, mystery-mode, onboarding, animation, appstorage]

requires:
  - phase: 03-01
    provides: Design token infrastructure (Colors, Typography, BrutalistModifiers, AppStorageKey, PizzaSliceShape)

provides:
  - Neobrutalist design system applied to every screen (carousel, permission views, compass calibration)
  - Mystery mode easter egg: leftmost carousel card with peeking emoji toggles classified-document redaction
  - OnboardingView: single-screen first-launch flow with pizza slice entrance animation
  - MysteryModeModifier: solid black bar redaction (not SwiftUI shimmer)
  - @AppStorage persistence for both mystery mode and onboarding completion

affects:
  - Any future UI work that adds screens or cards to the carousel

tech-stack:
  added: []
  patterns:
    - "MysteryRedacted ViewModifier pattern: overlay solid bar conditionally instead of .redacted(reason:)"
    - "Fixed UUID namespace for non-place carousel cards (00000000-0000-0000-0000-000000000000)"
    - "ShapeStyle dot shorthand (.pizzaOrange) fails in foregroundStyle context; must use Color.pizzaOrange explicitly"

key-files:
  created:
    - TakeMeToPizza/Views/MysteryModeModifier.swift
    - TakeMeToPizza/Views/OnboardingView.swift
  modified:
    - TakeMeToPizza/Views/CarouselView.swift
    - TakeMeToPizza/ContentView.swift
    - TakeMeToPizza/Views/CompassView.swift
    - TakeMeToPizza.xcodeproj/project.pbxproj

key-decisions:
  - "MysteryToggleCard uses fixed UUID 00000000-0000-0000-0000-000000000000 as carousel item ID -- never collides with place UUIDs"
  - "OnboardingView and MysteryModeModifier pbxproj IDs: FileRef AA000124/125, BuildFile AA000028/029"
  - "ShapeStyle shorthand (.pizzaOrange) does not resolve in foregroundStyle; must use Color.pizzaOrange explicitly"
  - "MysteryRedacted does not use .redacted(reason: .placeholder) -- that yields gray shimmer, not black bars"

patterns-established:
  - "All permission views use ZStack + Color.pizzaBackground.ignoresSafeArea() as base"
  - "Carousel scroll onChange guards against mysteryCardID to avoid non-place lookup"
  - "Mystery mode: redact name/address/phone/website; never redact distance or directions"

duration: 3min
completed: 2026-02-22
---

# Phase 3 Plan 02: Design System Application and Personality Features Summary

**Neobrutalist design applied to every screen via brutalistCard/brutalistButton tokens, mystery mode easter egg with classified-document redaction accessed by swiping left in carousel, and single-screen pizza slice onboarding for first-time users**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-02-22T04:14:25Z
- **Completed:** 2026-02-22T04:17:36Z
- **Tasks:** 2 of 2 auto tasks complete (checkpoint:human-verify pending)
- **Files modified:** 6

## Accomplishments

- All carousel cards now use `.brutalistCard()` with thick borders and hard offset shadows, custom pizza fonts, and pizza color palette -- no raw `Color.orange` remains
- Mystery mode toggle lives as the leftmost card in the carousel (swipe right to discover it); tapping toggles `@AppStorage`-persisted state that overlays solid black bars on place names, addresses, phone numbers, and website links; distance and directions button always remain visible
- First-time users see a minimal onboarding screen with a PizzaSliceShape illustration that springs into view, "FOLLOW THE PIZZA" heading, and a brutalist "LET'S GO" button; subsequent launches skip it entirely
- Permission views (priming, denied, restricted) all have pizza personality: wiggling pizza slice illustration on priming screen, upside-down sad slice for denied, pizza-orange lock for restricted

## Task Commits

Each task was committed atomically:

1. **Task 1 + partial Task 2: Restyle all views with neobrutalist design system** - `ad497ab` (feat)
2. **Task 2: Mystery mode, onboarding flow, and pbxproj registration** - `52f2aaf` (feat)

## Files Created/Modified

- `TakeMeToPizza/Views/CarouselView.swift` - Full brutalist restyle; MysteryToggleCard prepended; CardView takes mysteryModeEnabled parameter; AppStorage keys use AppStorageKey constants
- `TakeMeToPizza/ContentView.swift` - Onboarding gate wrapping permission switch; all permission views restyled with brutalist tokens and pizza personality copy
- `TakeMeToPizza/Views/CompassView.swift` - Calibration font sizes updated to pizzaDisplay(20) and pizzaBody(14)
- `TakeMeToPizza/Views/MysteryModeModifier.swift` (created) - MysteryRedacted ViewModifier, View extension, MysteryToggleCard
- `TakeMeToPizza/Views/OnboardingView.swift` (created) - Single-screen onboarding with spring-animated PizzaSliceShape
- `TakeMeToPizza.xcodeproj/project.pbxproj` - Registered OnboardingView.swift and MysteryModeModifier.swift

## Decisions Made

- **Fixed UUID for mystery card:** Used `UUID(uuidString: "00000000-0000-0000-0000-000000000000")!` as the stable ID for the MysteryToggleCard in the carousel LazyHStack. Avoids any possible collision with place UUIDs and is safely guarded in `onChange(of: scrollID)`.
- **Solid black bar instead of SwiftUI redaction:** `MysteryRedacted` overlays a `RoundedRectangle(cornerRadius: 3).fill(Color.primary)` rather than `.redacted(reason: .placeholder)`. The SwiftUI built-in yields a gray shimmer effect; the classified-document aesthetic requires an opaque solid bar.
- **ShapeStyle explicit Color prefix:** `.foregroundStyle(.pizzaOrange)` fails to compile because dot shorthand doesn't resolve through the `Color` extension in `ShapeStyle` context. Must use `Color.pizzaOrange` explicitly in all `foregroundStyle` calls.
- **pbxproj IDs:** OnboardingView.swift uses AA000124 (FileRef) / AA000028 (BuildFile); MysteryModeModifier.swift uses AA000125 (FileRef) / AA000029 (BuildFile).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed ShapeStyle shorthand compilation errors**
- **Found during:** Both Tasks 1 and 2 (CarouselView, ContentView, MysteryModeModifier)
- **Issue:** `.foregroundStyle(.pizzaOrange)` does not compile because `pizzaOrange` is defined as a `Color` extension property, and dot shorthand does not resolve through the `ShapeStyle` type alias in `foregroundStyle` context
- **Fix:** Replaced all `.foregroundStyle(.pizzaOrange)` with `.foregroundStyle(Color.pizzaOrange)` in CarouselView (StateCard), ContentView (PermissionRestrictedView), and MysteryModeModifier (MysteryToggleCard)
- **Files modified:** CarouselView.swift, ContentView.swift, MysteryModeModifier.swift
- **Verification:** Build succeeded with zero errors
- **Committed in:** ad497ab / 52f2aaf (part of task commits)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Necessary compiler fix. No scope creep. All intended functionality shipped as specified.

## Issues Encountered

None beyond the ShapeStyle compilation issue documented in deviations.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All of Phase 3 is complete pending human-verify checkpoint approval
- Human verification covers: onboarding gate, location priming personality, compass needle (physical device for tilt parallax), mystery mode full flow, dark mode, design system on all screens
- Once approved: Phase 3 is fully complete and the app is production-ready visually
- Physical device required for: tilt parallax (CMMotionManager), live compass rotation, sensory feedback

---
*Phase: 03-design-and-personality*
*Completed: 2026-02-22*
