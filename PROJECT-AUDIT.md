# Project Audit: Take Me To Pizza
*Generated: 2026-02-22*
*Stack: SwiftUI (iOS 17+) + MapKit + CoreLocation + CoreMotion*
*Type: Native iOS utility app — single-purpose pizza compass*
*Size: ~1,600 lines across 18 Swift files*

## Executive Summary

Take Me To Pizza is a well-architected, zero-dependency iOS app with strong brand personality and clean code organization. The core compass experience works. The biggest gaps are **accessibility** (no VoiceOver support, no reduced motion), **missing tactile feedback** (buttons have no press states or haptics), and **no app icon** (blocks App Store submission). The codebase is production-quality but needs polish on the edges — haptics, error recovery, and GPS accuracy warnings — before it's ready to ship.

## Critical Issues

| # | Issue | Category | File |
|---|-------|----------|------|
| 1 | **No app icon** — AppIcon.appiconset exists but contains no PNG | App Store | Assets.xcassets/AppIcon.appiconset/ |
| 2 | **No VoiceOver support** — zero accessibility labels across all views | Accessibility | All view files |
| 3 | **No reduced motion support** — all animations run regardless of user settings | Accessibility | CompassView, CarouselView, MysteryModeModifier, OnboardingView |
| 4 | **Task leak on rapid location updates** — unguarded `Task {}` in onChange can spawn concurrent fetches | Code Health | ContentView.swift:62-69 |

## Quick Wins

| # | Item | Effort | Impact |
|---|------|--------|--------|
| 1 | Add button press haptics (`.sensoryFeedback(.impact)` on all buttons) | 10 min | High — buttons feel dead without it |
| 2 | Add button press scale effect (`.scaleEffect(0.95)` on press) | 10 min | High — visual feedback on tap |
| 3 | Remove debug `print()` statement in LocationService | 1 min | Medium — stops console spam on device |
| 4 | Cap CurvedText arc to ~160° max so long names don't overlap | 10 min | High — "Giuseppe's Authentic Neapolitan Pizza" wraps the entire circle |
| 5 | Add `.accessibilityLabel()` to compass, cards, and buttons | 30 min | Critical — baseline VoiceOver support |
| 6 | Add `@Environment(\.accessibilityReduceMotion)` guards | 20 min | Critical — required for inclusive design |
| 7 | Add shimmer animation to loading skeleton | 10 min | Medium — static skeleton looks frozen |

## Findings by Category

### Code Health

- **HIGH** Task leak — `ContentView.swift:62-69`: `Task {}` in onChange spawns without cancellation. Rapid location changes create concurrent fetches. Use `.task(id:)` instead.
- **HIGH** N+1 in carousel — `CarouselView.swift:92-104`: `.onAppear` on every card re-evaluates entire places array. Compute threshold once outside the loop.
- **HIGH** Duplicate fetch paths — `ContentView.swift:25-36` and `:58-76` both trigger `fetchNearby()`. Race condition on first launch.
- **MEDIUM** O(M*N) deduplication — `PlacesService.swift:76-90`: loadMore checks every new place against every existing place with CLLocation distance calculations.
- **MEDIUM** URL string interpolation — `CarouselView.swift:293-309`: Coordinates interpolated directly into URL string. Use `URLComponents` for safety.
- **MEDIUM** Force-unwrap UUID — `CarouselView.swift:25`: `UUID(uuidString:)!` — safe in practice but sets a bad precedent.
- **LOW** Hardcoded search query — `PlacesService.swift:113`: `"pizza"` not configurable or localizable.

### UI/UX

- **CRITICAL** No VoiceOver labels — No `accessibilityLabel`, `accessibilityHint`, or `accessibilityElement` modifiers found anywhere.
- **HIGH** No reduced motion support — Spring animations, 360° spins, and compass rotation run regardless of `accessibilityReduceMotion` setting.
- **HIGH** No Dynamic Type — All fonts use fixed `Font.custom(size:)` with no scaling. Users with large text settings see no change.
- **HIGH** CurvedText overlaps on long names — Fixed 7.5° spacing means 36+ char names wrap past 260°.
- **MEDIUM** No color-alone distinction for alignment — Gold glow is the only indicator; colorblind users can't tell.
- **MEDIUM** Hardcoded carousel height (140/280pt) — No safe area consideration on notched devices.
- **MEDIUM** Compass needle fixed at 140×140pt — Not responsive to screen size (SE vs Pro Max).
- **MEDIUM** Calibration state has no dismiss/retry button — User is stuck until heading stabilizes.
- **MEDIUM** Missing placeholder content for empty place fields — Address/phone just vanish if nil.
- **LOW** Loading skeleton height (80pt) doesn't match actual card height (~140pt).
- **LOW** Permission view icon sizes inconsistent (100pt, 80pt, 80pt font).

### App Store & Launch Readiness

- **CRITICAL** No app icon PNG in AppIcon.appiconset — blocks submission.
- **MEDIUM** No privacy policy URL — required for App Store Connect metadata.
- **MEDIUM** Launch screen is default white — empty `UILaunchScreen` dict, no branded splash.
- **LOW** BebasNeue font still bundled in Info.plist UIAppFonts but no longer used (switched to Impact).
- All other requirements met: Info.plist keys, PrivacyInfo.xcprivacy, location permissions, bundle ID, code signing.

### Feature Completeness

- **HIGH** No GPS accuracy warning — compass gives wrong bearing with poor signal, user has no idea.
- **MEDIUM** No retry on network error — "Something went wrong" card says "Pull down to try again" but no pull-to-refresh exists.
- **MEDIUM** No settings screen — users can't change maps app preference after first choice, no units toggle, no about page.
- **MEDIUM** No share functionality — can't share a place with friends.
- **MEDIUM** No search/filter — only searches "pizza", no text filter.
- **MEDIUM** No places caching — refetches on every app launch.
- **LOW** No favorites or history (intentionally ephemeral per project design).
- **LOW** No map view alternative.
- **LOW** Distance unit ("slices") never explained to users.

### Polish & Delight

- **HIGH** Buttons have no press state — no scale, no opacity change, no haptic on tap.
- **HIGH** Card tap has no visual feedback — `.onTapGesture` with no animation response.
- **MEDIUM** Loading skeleton is static — no shimmer or pulse, looks frozen.
- **MEDIUM** Calibration text is generic — "Calibrating..." doesn't match the playful brand tone.
- **MEDIUM** Error states lack personality — "Something went wrong" is generic.
- **MEDIUM** No celebration on alignment — haptic fires but no visual reward when compass locks on.
- **LOW** Mystery mode needs more payoff — spin is fun but there's no reward/easter egg.
- **LOW** Onboarding is a single screen — no narrative about how the app works.

### Infrastructure & DevOps

- **HIGH** No linting — no SwiftLint or SwiftFormat configured.
- **MEDIUM** Minimal test coverage — only 4 unit tests (BearingMath). No tests for services, state, or views.
- **MEDIUM** No CI/CD — no GitHub Actions, no automated builds or test runs on PR.
- **LOW** No pre-commit hooks.
- Zero third-party dependencies (excellent).
- Project organization is clean and well-structured (excellent).
- In-code documentation is thorough (excellent).

## Prioritized Backlog

| # | Item | Category | Impact | Effort | Priority |
|---|------|----------|--------|--------|----------|
| 1 | Add app icon PNG (1024×1024) | App Store | Critical | Quick | **DO NOW** |
| 2 | Add VoiceOver accessibility labels to all views | Accessibility | Critical | Half-day | **DO NOW** |
| 3 | Add reduced motion support (`accessibilityReduceMotion`) | Accessibility | Critical | Quick | **DO NOW** |
| 4 | Fix Task leak — use `.task(id:)` for location fetches | Code Health | High | Quick | **Quick Win** |
| 5 | Add button press haptics + scale effect | Polish | High | Quick | **Quick Win** |
| 6 | Cap CurvedText arc to prevent overlap on long names | UI/UX | High | Quick | **Quick Win** |
| 7 | Remove debug print() in LocationService | Code Health | Medium | Quick | **Quick Win** |
| 8 | Add GPS accuracy warning banner | Features | High | Half-day | **Next Sprint** |
| 9 | Add retry button to error/no-network states | Features | Medium | Quick | **Quick Win** |
| 10 | Add shimmer animation to loading skeleton | Polish | Medium | Quick | **Quick Win** |
| 11 | Create privacy policy page (host externally) | App Store | Medium | Quick | **Quick Win** |
| 12 | Fix duplicate fetch race condition in ContentView | Code Health | High | Half-day | **Next Sprint** |
| 13 | Add Dynamic Type support to custom fonts | Accessibility | High | Half-day | **Next Sprint** |
| 14 | Add settings screen (maps preference, about, units) | Features | Medium | Half-day | **Next Sprint** |
| 15 | Add share button to expanded cards | Features | Medium | Half-day | **Next Sprint** |
| 16 | Add SwiftLint configuration | Infra | High | Half-day | **Next Sprint** |
| 17 | Fix N+1 query in carousel onAppear | Code Health | High | Quick | **Quick Win** |
| 18 | Add branded launch screen | App Store | Medium | Quick | **Backlog** |
| 19 | Add places caching with TTL | Features | Medium | Half-day | **Backlog** |
| 20 | Add calibration dismiss/retry button | UI/UX | Medium | Quick | **Backlog** |
| 21 | Add GitHub Actions CI workflow | Infra | Medium | Multi-day | **Backlog** |
| 22 | Expand unit test coverage to 60%+ | Infra | Medium | Multi-day | **Backlog** |
| 23 | Remove unused BebasNeue font from bundle | Cleanup | Low | Quick | **Backlog** |
| 24 | Add search/filter capability | Features | Medium | Multi-day | **Backlog** |
| 25 | Use URLComponents for maps deep links | Code Health | Medium | Quick | **Backlog** |

## Suggested Next Sprint

Focus: **Ship-ready polish** — fix the blockers, add the quick wins, make it feel premium.

1. Add app icon (pending your illustration)
2. Add VoiceOver accessibility labels across all views
3. Add reduced motion support
4. Add button press haptics + scale effects
5. Cap CurvedText arc for long names
6. Fix Task leak with `.task(id:)` pattern
7. Add retry button to error states
8. Create and host privacy policy
