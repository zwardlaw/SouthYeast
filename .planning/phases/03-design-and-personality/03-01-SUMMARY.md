---
phase: 03-design-and-personality
plan: 01
subsystem: design-system
tags: [swiftui, design-tokens, custom-fonts, coreMotion, brutalist, pizza-needle]
status: complete
duration: 17 min
completed: 2026-02-22

dependency-graph:
  requires:
    - 02-places-and-discovery (AppState.isAligned, CompassView structure, CarouselView overlay pattern)
  provides:
    - DesignSystem color tokens (pizzaRed, pizzaOrange, pizzaGold, pizzaCard, pizzaBackground)
    - Custom font wrappers (pizzaDisplay/Bebas Neue, pizzaBody/Space Grotesk)
    - BrutalistCard + BrutalistButton ViewModifiers
    - AppStorageKey centralized constants
    - PizzaSliceNeedle: pizza slice Shape + tilt parallax + alignment glow
    - MotionService: CMMotionManager wrapper for device roll/pitch
  affects:
    - 03-02 (consumes all design tokens and brutalist modifiers for full app restyling)

tech-stack:
  added:
    - CoreMotion (CMMotionManager, CMDeviceMotion.attitude)
    - BebasNeue-Regular.ttf (display typeface)
    - SpaceGrotesk-VariableFont_wght.ttf (body typeface, 400 weight static)
  patterns:
    - Color token pattern via Asset Catalog colorsets (Any/Dark adaptive)
    - ViewModifier composition for brutalist card/button styles
    - @Observable @MainActor pattern for CMMotionManager (Swift 6 safe)
    - rotation3DEffect dual-axis for fake-3D tilt parallax
    - onChange(of: isAligned) + DispatchQueue.asyncAfter for pulse animation reset

key-files:
  created:
    - TakeMeToPizza/DesignSystem/Colors.swift
    - TakeMeToPizza/DesignSystem/Typography.swift
    - TakeMeToPizza/DesignSystem/BrutalistModifiers.swift
    - TakeMeToPizza/DesignSystem/AppStorageKey.swift
    - TakeMeToPizza/Views/PizzaSliceNeedle.swift
    - TakeMeToPizza/Services/MotionService.swift
    - TakeMeToPizza/Resources/Assets.xcassets/Colors/PizzaRed.colorset/Contents.json
    - TakeMeToPizza/Resources/Assets.xcassets/Colors/PizzaOrange.colorset/Contents.json
    - TakeMeToPizza/Resources/Assets.xcassets/Colors/PizzaGold.colorset/Contents.json
    - TakeMeToPizza/Resources/Assets.xcassets/Colors/PizzaBackground.colorset/Contents.json
    - TakeMeToPizza/Resources/Assets.xcassets/Colors/PizzaCard.colorset/Contents.json
    - TakeMeToPizza/Resources/Fonts/BebasNeue-Regular.ttf
    - TakeMeToPizza/Resources/Fonts/SpaceGrotesk-VariableFont_wght.ttf
  modified:
    - TakeMeToPizza/Views/CompassView.swift (PizzaSliceNeedle, design tokens, scenePhase lifecycle)
    - TakeMeToPizza/Info.plist (UIAppFonts array)
    - TakeMeToPizza.xcodeproj/project.pbxproj (all new files registered)

decisions:
  - id: 03-01-A
    decision: "PBXBuildFile IDs AA000022/023 collided with existing PBXFrameworksBuildPhase objects; renamed to AA000026/027"
    why: "pbxproj has AA000020=Frameworks(app), AA000021=Resources(app), AA000022=Frameworks(test) -- plan's ID assignment assumed these were free"
    impact: "No functional change; IDs AA000026/027 used instead of plan's AA000022/023"
  - id: 03-01-B
    decision: "PBXFileReference IDs AA000120/121 reserved for fonts became AA000122/123 -- AA000120 already used for TakeMeToPizzaTests.xctest"
    why: "Plan pre-assigned AA000120/121 without checking existing usage"
    impact: "No functional change; font references use AA000122/123"
  - id: 03-01-C
    decision: "Space Grotesk downloaded as static 400-weight TTF (SpaceGrotesk-Regular PostScript name) rather than variable font"
    why: "Google Fonts API returns woff2 for variable font with all user agents; static TTF available at fonts.gstatic.com; static 400 maps correctly to PostScript name SpaceGrotesk-Regular used in Typography.swift"
    impact: "Font renders at regular weight only; variable weight range not available. Acceptable -- app uses regular body weight throughout"
  - id: 03-01-D
    decision: "MotionService lifecycle in CompassView via scenePhase + onAppear/onDisappear rather than app-level environment"
    why: "Per RESEARCH.md recommendation; only runs when compass is visible; battery safe"
    impact: "Clean separation -- MotionService auto-stops during onboarding/permission flows"
---

# Phase 3 Plan 01: Design System and Pizza Needle Summary

**One-liner:** Pizza slice compass needle with CMMotionManager tilt parallax + Bebas Neue/Space Grotesk design system on pizzaRed/Orange/Gold/Background palette with brutalist card/button ViewModifiers.

## What Was Built

The complete design infrastructure for the app, plus the single most important visual: the pizza slice compass needle.

### Design System Foundation

`TakeMeToPizza/DesignSystem/` contains four files:

- **Colors.swift** -- `Color.pizzaRed`, `.pizzaOrange`, `.pizzaGold`, `.pizzaCard`, `.pizzaBackground` each referencing an Asset Catalog colorset with adaptive Any/Dark appearances
- **Typography.swift** -- `Font.pizzaDisplay(size:)` (Bebas Neue) and `Font.pizzaBody(size:)` (Space Grotesk) with `.pizzaCaption`/`.pizzaHeadline` convenience sizes
- **BrutalistModifiers.swift** -- `BrutalistCard` and `BrutalistButton` ViewModifiers with hard offset shadows (`radius: 0, x: 3, y: 3`) and `Color.primary` borders (dark-mode adaptive)
- **AppStorageKey.swift** -- centralized `static let` string constants replacing inline literals

### Pizza Slice Needle

`PizzaSliceNeedle.swift` contains:

- **PizzaSliceShape** -- a `Shape` that draws a 36-degree pizza sector pointing at 12 o'clock using `addArc(center:radius:startAngle:endAngle:clockwise: false)`. The `clockwise: false` parameter correctly draws left-to-right given SwiftUI's flipped Y coordinate system.
- **PizzaSliceNeedle** -- the composed view with:
  - Orange cheese fill (dimmed when not aligned, warm when aligned, animated `.easeInOut`)
  - Red crust stroke overlay
  - Three `PepperoniOverlay` circles at fixed positions
  - Gold shadow glow on `isAligned` (animated `.easeInOut(duration: 0.3)`)
  - Pulse ring: `Circle` stroke that scales from 1.0 to 1.6 and fades, repeating while aligned
  - Two `rotation3DEffect` calls: roll on Y-axis, pitch on X-axis (both scaled to 15 degrees max)

### MotionService

`Services/MotionService.swift` -- `@Observable @MainActor final class` wrapping `CMMotionManager`:
- Updates at 20 Hz via `startDeviceMotionUpdates(to: .main)`
- Exposes `roll: Double` and `pitch: Double` from `CMDeviceMotion.attitude`
- `start()`/`stop()` API; no-op on Simulator (hardware unavailable guard)

### CompassView Upgrade

The SF Symbol `location.north.fill` placeholder is completely replaced:
- `PizzaSliceNeedle(motionService:isAligned:)` with spring rotation animation
- `Color.pizzaBackground.ignoresSafeArea()` as ZStack background
- Calibration text styled with `.pizzaDisplay(size: 28)` and `Color.pizzaOrange`
- Target place name uses `.pizzaDisplay(size: 24)`
- `scenePhase` `.onChange` stops/starts MotionService on background/active

## Decisions Made

| ID | Decision | Impact |
|----|----------|--------|
| 03-01-A | PBXBuildFile IDs AA000026/027 (not 022/023 -- those collided with existing Frameworks build phases) | IDs only; no functional impact |
| 03-01-B | Font PBXFileReference IDs AA000122/123 (not 120/121 -- AA000120 was TakeMeToPizzaTests.xctest) | IDs only; no functional impact |
| 03-01-C | Space Grotesk static 400-weight TTF (variable font not available as TTF from public CDN) | Regular weight only; acceptable for current usage |
| 03-01-D | MotionService view-scoped in CompassView, not app-level environment | Battery-safe; only runs when compass visible |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] PBXBuildFile ID conflicts with existing build phase objects**

- **Found during:** Task 3
- **Issue:** Plan specified AA000022/023 for PizzaSliceNeedle/MotionService build files, but AA000022 was already the test target's PBXFrameworksBuildPhase object. Similarly AA000120/121 were reserved for font PBXFileReferences but AA000120 was TakeMeToPizzaTests.xctest
- **Fix:** Renamed conflicting build file IDs to AA000026/027 and font references to AA000122/123
- **Files modified:** TakeMeToPizza.xcodeproj/project.pbxproj
- **Commit:** f331da7

**2. [Rule 1 - Bug] Unused `rightEdge` variable warning in PizzaSliceNeedle**

- **Found during:** Task 3 (first build)
- **Issue:** `rightEdge` computed for geometric reference but not directly used (addArc uses angle, not endpoint)
- **Fix:** Changed to `_ = CGPoint(...)` to suppress warning with explanatory comment
- **Files modified:** TakeMeToPizza/Views/PizzaSliceNeedle.swift
- **Commit:** f331da7

**3. Space Grotesk variable TTF unavailable from public CDN**

- **Found during:** Task 1
- **Issue:** Google Fonts download API returns HTML. The official Space Grotesk GitHub repo (floriankarsten) tag v3.0.0 returns 404. The variable font is only available as woff2 from Google Fonts API
- **Fix:** Downloaded static 400-weight TTF from `fonts.gstatic.com` (Google Fonts CDN), which correctly uses the PostScript name "SpaceGrotesk-Regular" specified in Typography.swift
- **Impact:** Font displays at regular weight. Variable weight range not available -- acceptable for current usage

## Next Phase Readiness

Plan 02 (full app restyling) can proceed. All design tokens are available:
- `Color.pizza*` tokens for all surfaces
- `Font.pizzaDisplay(size:)` and `Font.pizzaBody(size:)` for all text
- `.brutalistCard()` and `.brutalistButton()` modifiers for UI components
- `AppStorageKey` constants for existing @AppStorage usages in CarouselView

The pizza needle is the app's hero visual and renders in CompassView. Plan 02 focuses on applying design tokens to the remaining views (permission screens, carousel cards, distance labels).
