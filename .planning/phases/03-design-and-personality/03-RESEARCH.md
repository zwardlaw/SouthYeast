# Phase 3: Design and Personality - Research

**Researched:** 2026-02-21
**Domain:** SwiftUI design systems, custom shapes, CoreMotion, custom fonts, animation, haptics, persistence
**Confidence:** HIGH (all major claims verified with official docs or authoritative sources)

---

## Summary

Phase 3 transforms a functional compass into a bold, physical, branded experience. The work falls into five distinct technical tracks: (1) a neobrutalist design system implemented as SwiftUI ViewModifiers and Color extensions, (2) a custom pizza-slice Shape with Path drawing and a CoreMotion tilt effect, (3) mystery mode with @AppStorage persistence and a custom redaction overlay, (4) onboarding and location priming screens gated by @AppStorage first-launch detection, and (5) two bundled custom fonts registered via Info.plist.

Every domain uses Apple-native APIs exclusively. No third-party Swift packages are needed. The two font files (Bebas Neue + Space Grotesk) are the only non-code assets to add, and both carry the SIL OFL license permitting commercial bundling.

The most technically novel piece is the pizza slice needle: a custom Shape drawn with Path's arc API, with a device-tilt parallax effect driven by CMMotionManager reading pitch/roll and applying `.rotation3DEffect()` in two axes. This pattern is well-documented and straightforward in SwiftUI.

**Primary recommendation:** Build the design system (ViewModifiers + Color tokens + Font extensions) first as a foundation. Every other visual deliverable in this phase will consume it.

---

## Standard Stack

All Apple-native. Zero new Swift package dependencies.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ (already required) | All visual layers | Already in use; ViewModifier protocol is the canonical extensibility point |
| CoreMotion | iOS 17+ | Device tilt for pizza needle parallax | Apple-native; `CMMotionManager` is the only API for device attitude |
| UserDefaults / @AppStorage | iOS 14+ | Mystery mode persistence, onboarding flag | SwiftUI-native; survives app restarts, zero boilerplate |

### Font Files (Non-Code Assets)
| Font | Use | License | Download |
|------|-----|---------|----------|
| Bebas Neue | Display / header | SIL OFL (free, commercial bundle OK) | [github.com/dharmatype/Bebas-Neue](https://github.com/dharmatype/Bebas-Neue) or Google Fonts |
| Space Grotesk | Body / UI labels | SIL OFL | [fonts.google.com/specimen/Space+Grotesk](https://fonts.google.com/specimen/Space+Grotesk) |

**Why these two:** Bebas Neue is the canonical neobrutalist display font — all-caps, compressed, maximum impact at large sizes, consistent with the "thick borders / bold type" aesthetic. Space Grotesk is a modern geometric grotesque with quirky details that pair naturally with Bebas Neue for body copy and card labels without competing. Both are SIL OFL, well-tested on iOS, and widely documented.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bebas Neue | Syne Extra | Syne is variable-weight and slightly more playful; Bebas is more aggressive and better-known as neobrutalist header |
| Space Grotesk | DM Sans | DM Sans is cleaner/more neutral; Space Grotesk has more personality that matches the brand |
| @AppStorage | UserDefaults directly | @AppStorage auto-triggers SwiftUI redraws; raw UserDefaults requires manual observation |

### Installation

No `swift package` commands needed. Font files only:
```
1. Download BebasNeue-Regular.ttf from github.com/dharmatype/Bebas-Neue
2. Download SpaceGrotesk-VariableFont_wght.ttf from fonts.google.com
3. Drag into Xcode project → TakeMeToPizza target → Copy items if needed
4. Add to Info.plist (see Code Examples section)
```

---

## Architecture Patterns

### Recommended Project Structure
```
TakeMeToPizza/
├── DesignSystem/
│   ├── Colors.swift          # Color extension with pizza palette tokens
│   ├── Typography.swift      # Font extension wrapping Font.custom()
│   ├── BrutalistModifiers.swift  # ViewModifiers: .brutalistCard(), .brutalistButton(), etc.
│   └── HapticEngine.swift    # Thin wrapper for UIImpactFeedbackGenerator patterns
├── Views/
│   ├── CompassView.swift     # Existing — replace SFSymbol with PizzaSliceNeedle
│   ├── CarouselView.swift    # Existing — add mystery mode redaction, brutalist card style
│   ├── ContentView.swift     # Existing — add onboarding gate
│   ├── OnboardingView.swift  # New — single screen, tap to start
│   ├── PizzaSliceNeedle.swift  # New — custom Shape + MotionManager tilt
│   └── MysteryModeModifier.swift  # New — redaction overlay ViewModifier
├── Services/
│   └── MotionService.swift   # New — @Observable CMMotionManager wrapper
└── Assets.xcassets/
    └── Colors/               # Color sets for light + dark mode adaptive tokens
```

### Pattern 1: Design Token ViewModifiers

Create one `BrutalistModifiers.swift` file that contains all ViewModifiers for the design system. Each modifier is accessed via a `View` extension for clean call-site syntax.

**What:** Custom ViewModifiers encode the neobrutalist visual language — thick borders, hard offset shadows, bold backgrounds — as reusable, composable units.
**When to use:** Every card, button, and container in the app.

```swift
// Source: ViewModifier protocol — developer.apple.com/documentation/swiftui/viewmodifier
struct BrutalistCard: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(Color.pizzaCard)          // from Color extension
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.primary, lineWidth: 2.5)
            )
            .shadow(color: Color.primary.opacity(0.9), radius: 0, x: 3, y: 3)
    }
}

struct BrutalistButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("BebasNeue-Regular", size: 18))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.pizzaRed)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary, lineWidth: 2)
            )
            .shadow(color: Color.primary.opacity(0.9), radius: 0, x: 3, y: 3)
    }
}

extension View {
    func brutalistCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(BrutalistCard(cornerRadius: cornerRadius))
    }
    func brutalistButton() -> some View {
        modifier(BrutalistButton())
    }
}
```

**Soft brutalist parameters (per CONTEXT.md decisions):**
- Border width: 2–2.5pt (not 4pt — this is "soft" brutalist, not aggressive)
- Shadow offset: x: 3, y: 3 (hard offset, radius: 0)
- Corner radius: 8–16pt depending on element size
- Shadow opacity: 0.8–0.9 (near-solid, not diffuse)

### Pattern 2: Adaptive Color Tokens

```swift
// Source: Swift by Sundell — swiftbysundell.com/articles/defining-dynamic-colors-in-swift/
// Colors.swift
extension Color {
    // Pizza palette — light mode / dark mode adaptive
    static let pizzaRed     = Color("PizzaRed")      // Asset Catalog color set
    static let pizzaOrange  = Color("PizzaOrange")
    static let pizzaGold    = Color("PizzaGold")
    static let pizzaCard    = Color("PizzaCard")      // light: .white, dark: .near-black warm
    static let pizzaBackground = Color("PizzaBackground")

    // Programmatic adaptive colors (alternative to Asset Catalog)
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
```

**Pizza palette (soft brutalist):**
- Light mode: off-white background `#FDFAF5`, deep red `#C0392B`, warm orange `#E67E22`, golden yellow `#F1C40F`
- Dark mode: warm near-black `#1A1007`, muted red `#E74C3C`, amber orange `#E67E22`, golden `#F39C12`
- Card background: light `#FFFFFF` / dark `#2D1B0E` (warm brown-black, not cold gray)

**Recommendation:** Use Xcode Asset Catalog Color Sets for the named tokens. This gives free dark mode support with the "Appearances: Any, Dark" toggle in the asset editor — simpler than writing adaptive UIColor closures for every color.

### Pattern 3: Custom Font Extension

```swift
// Typography.swift
extension Font {
    static func pizzaDisplay(size: CGFloat) -> Font {
        .custom("BebasNeue-Regular", size: size)
    }
    static func pizzaBody(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Space Grotesk variable font — use PostScript name
        .custom("SpaceGrotesk-\(weight.postscriptSuffix)", size: size)
    }
}

// Usage in views:
Text("TAKE ME TO PIZZA")
    .font(.pizzaDisplay(size: 32))

Text(place.name)
    .font(.pizzaBody(size: 16, weight: .semibold))
```

**Critical:** The string passed to `Font.custom()` must be the PostScript name, NOT the filename. To find it: open the font in Font Book app → Get Info → PostScript Name. For Bebas Neue it is `"BebasNeue-Regular"`. For Space Grotesk variable font it may be `"SpaceGrotesk-Regular"` (verify with Font Book after adding to project).

### Pattern 4: Pizza Slice Shape

The needle replaces the SF Symbol `location.north.fill` in `CompassView.swift`. It is a custom `Shape` that draws a pizza slice pointing "up" (toward 12 o'clock in the SwiftUI coordinate system).

```swift
// Source: SwiftUI Path API — developer.apple.com/tutorials/swiftui/drawing-paths-and-shapes
struct PizzaSliceShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let tipAngle: Double = -90    // 12 o'clock (SwiftUI: 0 = 3 o'clock, -90 = up)
        let sliceHalfAngle: Double = 18  // 36-degree wide slice

        // Start at tip (center)
        path.move(to: center)
        // Draw to left crust edge
        let leftEdge = CGPoint(
            x: center.x + radius * cos((tipAngle - sliceHalfAngle) * .pi / 180),
            y: center.y + radius * sin((tipAngle - sliceHalfAngle) * .pi / 180)
        )
        path.addLine(to: leftEdge)
        // Arc across crust
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(tipAngle - sliceHalfAngle),
            endAngle: .degrees(tipAngle + sliceHalfAngle),
            clockwise: false
        )
        path.closeSubpath()   // closes back to center (tip)
        return path
    }
}
```

**Key gotcha:** SwiftUI's `addArc` measures angles from the 3 o'clock position (0°), going clockwise. So "pointing up" is -90°. The `clockwise` parameter behavior is visually inverted because SwiftUI uses a flipped Y-axis. Use `clockwise: false` for a normal left-to-right arc.

**Usage in CompassView:**
```swift
// Replace the Image(systemName: "location.north.fill") block
PizzaSliceNeedle()   // custom View that wraps Shape + tilt effect
    .frame(width: 180, height: 180)
    .rotationEffect(.degrees(appState.compassAngle))
    .animation(.interpolatingSpring(stiffness: 170, damping: 26), value: appState.compassAngle)
```

### Pattern 5: CMMotionManager for Tilt Parallax

The pizza slice gets a fake-3D tilt effect via CMMotionManager reading device pitch and roll, then applying two stacked `.rotation3DEffect()` calls.

```swift
// Source: createwithswift.com/using-core-motion-within-a-swiftui-application/
// MotionService.swift
import CoreMotion
import Observation

@Observable
@MainActor
final class MotionService {
    var roll: Double = 0.0
    var pitch: Double = 0.0

    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 20.0   // 20Hz — smooth without draining battery
        // .main queue avoids Sendable crossing — handler runs on MainActor directly
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            guard let attitude = data?.attitude else { return }
            self?.roll = attitude.roll
            self?.pitch = attitude.pitch
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
```

**Swift 6 note:** `CMMotionManager` is not `Sendable`. The safe pattern is `startDeviceMotionUpdates(to: .main)` — this dispatches the handler on the main thread, keeping all property mutations on `@MainActor`. Do NOT use a background OperationQueue for UI-updating properties.

**Applying tilt to the needle:**
```swift
// Source: createwithswift.com/using-core-motion-within-a-swiftui-application/
PizzaSliceShape()
    .fill(Color.pizzaOrange)
    .rotation3DEffect(
        .degrees(motionService.roll * 15),    // lean left/right
        axis: (x: 0, y: 1, z: 0)
    )
    .rotation3DEffect(
        .degrees(motionService.pitch * 15),   // lean forward/back
        axis: (x: -1, y: 0, z: 0)
    )
```

**Multiplier 15:** Scales the radian roll/pitch value (roughly -0.5 to 0.5 for normal tilts) to a visual degree range of -7.5 to 7.5 degrees — enough to feel physical without being disorienting. Adjust via trial on device.

**`perspective` parameter:** `.rotation3DEffect` has an optional `perspective:` parameter defaulting to 1.0. Values around 0.3–0.5 produce a subtler, less distorted tilt. For this feature, default (1.0) or 0.5 both work.

### Pattern 6: Mystery Mode — @AppStorage + Redaction

**Persistence:**
```swift
// In CarouselView or AppState — @AppStorage is view-independent
@AppStorage("mysteryModeEnabled") private var mysteryModeEnabled: Bool = false
```

`@AppStorage` automatically syncs to `UserDefaults.standard`. Multiple views can declare the same key and they all stay in sync via SwiftUI's update mechanism.

**Redaction overlay (classified document bars):**
```swift
// Source: fivestars.blog/articles/redacted-custom-effects/
// MysteryModeModifier.swift
struct MysteryRedacted: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                isActive
                    ? AnyView(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.primary)  // black in light, white in dark
                            .padding(.vertical, 2)
                    )
                    : AnyView(EmptyView())
            )
            .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

extension View {
    func mysteryRedacted(isActive: Bool) -> some View {
        modifier(MysteryRedacted(isActive: isActive))
    }
}
```

**Usage in CardView:**
```swift
Text(place.name)
    .font(.pizzaBody(size: 16, weight: .semibold))
    .mysteryRedacted(isActive: mysteryModeEnabled)

Text(place.address)
    .mysteryRedacted(isActive: mysteryModeEnabled)
```

**Do NOT use SwiftUI's built-in `.redacted(reason: .placeholder)` for this.** The built-in redaction uses a gray shimmer, not a solid bar. The "classified document" aesthetic requires a solid opaque overlay, which the custom modifier above provides.

### Pattern 7: Onboarding Gate via @AppStorage

```swift
// ContentView.swift — wrap the switch statement
@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

var body: some View {
    Group {
        if !hasCompletedOnboarding {
            OnboardingView(onComplete: { hasCompletedOnboarding = true })
        } else {
            // Existing permission switch
            switch locationService.permissionStatus {
            case .notDetermined: PermissionPrimingView()
            case .denied:        PermissionDeniedView()
            case .restricted:    PermissionRestrictedView()
            case .authorized:    CompassView()
            }
        }
    }
}
```

**Onboarding flow:** Shown once only (first install). After user taps the CTA, `hasCompletedOnboarding` is set to `true`, and the onboarding never shows again.

**Onboarding screen structure:**
```swift
struct OnboardingView: View {
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.pizzaBackground.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                // Large pizza slice illustration (drawn with PizzaSliceShape or SF Symbol placeholder)
                PizzaSliceShape()
                    .fill(Color.pizzaOrange)
                    .frame(width: 160, height: 160)

                Text("FOLLOW THE PIZZA")
                    .font(.pizzaDisplay(size: 36))
                    .multilineTextAlignment(.center)

                Spacer()

                Button("LET'S GO") { onComplete() }
                    .brutalistButton()
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
    }
}
```

### Pattern 8: Alignment Glow + Pulse

When `appState.isAligned == true`, the needle shows a glow + pulse effect.

```swift
// Pulse overlay on the pizza slice
.overlay(
    Circle()
        .stroke(Color.pizzaGold.opacity(isPulsing ? 0 : 0.6), lineWidth: 3)
        .scaleEffect(isPulsing ? 1.4 : 1.0)
        .animation(
            .easeOut(duration: 0.8).repeatForever(autoreverses: false),
            value: isPulsing
        )
)
// Glow via shadow
.shadow(color: Color.pizzaGold.opacity(appState.isAligned ? 0.7 : 0), radius: 12)
.animation(.easeInOut(duration: 0.3), value: appState.isAligned)
```

**Haptic (already in codebase):** The existing `.sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7), trigger: appState.isAligned)` in CompassView is the right approach. Keep it.

### Anti-Patterns to Avoid

- **Using `.redacted(reason: .placeholder)` for mystery mode:** Produces gray shimmer, not black bars. Use the custom overlay modifier instead.
- **Using a background queue for CMMotionManager + @Observable:** `@MainActor @Observable` properties must be mutated on the main thread. Always pass `.main` as the OperationQueue.
- **Embedding font by filename instead of PostScript name:** `Font.custom("BebasNeue-Regular.ttf", size: 24)` will silently fail; use the PostScript name without extension.
- **Forgetting Info.plist `UIAppFonts` array:** Font files added to the bundle are invisible to the system until registered. Adding the `.ttf` filename to the `UIAppFonts` key (not "Fonts provided by application" — both work but `UIAppFonts` is the raw key name) is mandatory.
- **Hard-coding `Color.black` for borders:** In dark mode this inverts badly. Use `Color.primary` which is black in light mode and white in dark mode, matching the neobrutalist "always-contrast" look.
- **Clamping compassAngle to 0-360 in the design layer:** The existing `compassAngle` accumulates continuously (prevents spin-over). Don't reset it when applying `.rotationEffect()`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Device tilt sensing | Custom accelerometer math | `CMMotionManager.attitude` (pitch/roll) | Attitude already integrates gyroscope + accelerometer for stable values |
| Font loading | Dynamic font registration at runtime | Info.plist `UIAppFonts` + bundle | CTFontManager registration works but is unnecessary when bundling |
| Haptics | Raw AudioServicesPlaySystemSound | `.sensoryFeedback()` modifier or `UIImpactFeedbackGenerator` | Already correct in codebase; do not change |
| Color adaptation | Manual `@Environment(\.colorScheme)` checks everywhere | Asset Catalog color sets + `Color.primary` | Asset Catalog is free, correct, and less fragile |
| First-launch detection | Custom class with UserDefaults | `@AppStorage("hasCompletedOnboarding") Bool = false` | One line; reactive; survives view recreation |

**Key insight:** This phase adds no new business logic. Every technical pattern (shape drawing, tilt, persistence, haptics) has a well-documented Apple-native path that is 5-20 lines of code. Complexity lives in visual polish, not in infrastructure.

---

## Common Pitfalls

### Pitfall 1: Font PostScript Name Mismatch

**What goes wrong:** `Font.custom("Bebas Neue", size: 24)` silently falls back to system font. No error is thrown.
**Why it happens:** `Font.custom()` takes the PostScript name, which often differs from the display name or filename.
**How to avoid:** After adding the font file, open Terminal and run `fc-list | grep -i bebas` or open Font Book → select font → File → Get Info → PostScript Name. Use that exact string.
**Warning signs:** Text renders in system font (SF Pro) rather than the display typeface.

### Pitfall 2: CMMotionManager Not Stopped on Background

**What goes wrong:** App continues receiving motion updates in background, draining battery; iOS may terminate the app.
**Why it happens:** `startDeviceMotionUpdates` runs until explicitly stopped.
**How to avoid:** Call `motionService.stop()` in `.onChange(of: scenePhase)` when phase becomes `.background`, and `motionService.start()` when `.active`. The existing `ContentView` already has a `scenePhase` handler — add motion calls there.
**Warning signs:** High energy impact in Xcode's debug navigator.

### Pitfall 3: @AppStorage Key Typos Across Views

**What goes wrong:** `CardView` reads `"mysteryMode"` but the toggle writes `"mysteryModeEnabled"` — mystery mode appears to not persist.
**Why it happens:** @AppStorage keys are raw strings; no compiler enforcement.
**How to avoid:** Define key constants in one place:
```swift
enum AppStorageKey {
    static let mysteryMode = "mysteryModeEnabled"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}
```
**Warning signs:** Mystery mode or onboarding resets unexpectedly between launches.

### Pitfall 4: rotation3DEffect Clipping the Shadow

**What goes wrong:** The offset box shadow on brutalist cards gets clipped at the view boundary when rotation3DEffect is applied to the needle.
**Why it happens:** rotation3DEffect is a rendering transform; it doesn't expand the view's layout bounds. Shadows applied before 3D rotation may clip.
**How to avoid:** Apply the neobrutalist border/shadow to wrapper containers, not to the element receiving 3D rotation. Keep PizzaSliceNeedle as a pure shape + fill + rotation; put brutalist chrome on its parent.

### Pitfall 5: addArc Clockwise Direction Confusion

**What goes wrong:** The pizza slice arc draws in the wrong direction, filling the wrong half of the circle.
**Why it happens:** SwiftUI's coordinate system has a flipped Y-axis, which visually inverts the `clockwise` parameter. `clockwise: true` appears counterclockwise.
**How to avoid:** Draw the arc and test visually in Simulator. Swap `clockwise: true` ↔ `false` if the slice is inverted. This is documented community knowledge — not a bug.
**Warning signs:** The arc covers ~300 degrees instead of ~36 degrees.

### Pitfall 6: Simulator Cannot Test CoreMotion

**What goes wrong:** Tilt effect appears static/broken in Simulator.
**Why it happens:** Simulator does not simulate gyroscope or accelerometer.
**How to avoid:** Add a guard in `MotionService.start()` checking `manager.isDeviceMotionAvailable`. On Simulator this returns `false` and motion updates are skipped gracefully — the pizza slice still renders and rotates to target; it just doesn't tilt. All tilt testing requires a physical device.

---

## Code Examples

### Bundling Fonts — Info.plist

```xml
<!-- In TakeMeToPizza/Info.plist, add the UIAppFonts array -->
<key>UIAppFonts</key>
<array>
    <string>BebasNeue-Regular.ttf</string>
    <string>SpaceGrotesk-VariableFont_wght.ttf</string>
</array>
```

Alternatively in Xcode: Target → Info tab → + → "Fonts provided by application" → add each filename.

### Mystery Mode Toggle Card (Carousel leftmost card)

```swift
// The "mystery mode" card is a special leading card in the carousel
// It appears at index 0, before the places array
struct MysteryToggleCard: View {
    @AppStorage(AppStorageKey.mysteryMode) private var mysteryModeEnabled: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            Text(mysteryModeEnabled ? "🫣" : "🫣")
                .font(.system(size: 48))
            Text(mysteryModeEnabled ? "Mystery ON" : "")
                .font(.pizzaBody(size: 12))
                .foregroundStyle(.secondary)
                .opacity(mysteryModeEnabled ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .brutalistCard()
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                mysteryModeEnabled.toggle()
            }
        }
    }
}
```

The carousel already uses `scrollPosition(id:)` and `scrollTargetBehavior(.viewAligned)`. Prepend the `MysteryToggleCard` as the first item. When the user swipes right past it, they discover it organically.

### Sensory Feedback (existing codebase reference)

The app already uses `.sensoryFeedback` — the Phase 3 addition is adding alignment feedback to the glow trigger:

```swift
// Already in CompassView — keep this:
.sensoryFeedback(
    .impact(flexibility: .rigid, intensity: 0.7),
    trigger: appState.isAligned
)

// Add a second feedback for mystery mode toggle:
.sensoryFeedback(.selection, trigger: mysteryModeEnabled)
```

### Color Asset Catalog Setup (Xcode)

```
Assets.xcassets/
└── Colors/
    ├── PizzaRed.colorset/Contents.json
    │   Any: #C0392B, Dark: #E74C3C
    ├── PizzaOrange.colorset/Contents.json
    │   Any: #E67E22, Dark: #E67E22
    ├── PizzaGold.colorset/Contents.json
    │   Any: #F1C40F, Dark: #F39C12
    ├── PizzaBackground.colorset/Contents.json
    │   Any: #FDFAF5, Dark: #1A1007
    └── PizzaCard.colorset/Contents.json
        Any: #FFFFFF, Dark: #2D1B0E
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `@ObservableObject` + `@Published` | `@Observable` macro | Swift 5.9 / iOS 17 | MotionService should use `@Observable`; already used in LocationService |
| `ObservableObject` + `.environmentObject` | `@Observable` + `.environment()` | iOS 17 | Already done in this codebase |
| UIKit haptics (`UIImpactFeedbackGenerator`) | `.sensoryFeedback()` modifier | iOS 17 | Simpler; already used in CompassView |
| Manual `UserDefaults.standard.set()` | `@AppStorage` | iOS 14 | Already used in CarouselView (`preferredMapsApp`) |
| `rotation3DEffect` only for 3D | `rotation3DEffect` stacked twice for dual-axis | Always available | Standard pattern for device-tilt parallax |

**Deprecated/outdated:**
- `@ObservableObject` in new classes: Still works but `@Observable` is preferred for iOS 17+ targets
- `UIImpactFeedbackGenerator` called manually: Still works; `.sensoryFeedback()` is preferred in SwiftUI views

---

## Open Questions

1. **Pizza slice illustration detail level**
   - What we know: The shape will be drawn with SwiftUI Path. Simple geometric slice is easy; detailed (cheese bubbles, pepperoni dots) requires layered shapes or an asset.
   - What's unclear: Whether visual fidelity should come from Path complexity (all code) or an SVG/PDF asset overlaid on the shape (easier artistically, slightly more asset work).
   - Recommendation: Start with a pure Path solution (slice outline + a few filled circles for "pepperoni" and a fill gradient for "cheese"). Can always swap in an image asset if the Path approach looks too plain. Keep it code-driven to avoid asset management.

2. **"Cooked/cold" temperature feedback**
   - What we know: Per CONTEXT.md, this is aspirational for this phase. Glow + pulse is the fallback.
   - What's unclear: Whether a color temperature shift (warm orange when facing target → cool blue when facing away) is feasible within the design system without clashing with the pizza palette.
   - Recommendation: Implement glow + pulse as the primary alignment feedback. Add a color tint modifier on the needle (`foregroundStyle(alignmentColor)`) that shifts between `pizzaGold` (aligned) and a desaturated version (misaligned). This is 1-2 lines and delivers the temperature concept without blue (which would clash with the warm palette).

3. **MotionService injection pattern**
   - What we know: The app uses `.environment()` for all services. `MotionService` should follow the same pattern.
   - What's unclear: `MotionService` is only needed in `CompassView` — should it be app-wide environment or local `@State` in `CompassView`?
   - Recommendation: Declare as `@State private var motionService = MotionService()` inside `CompassView` (or its parent). No need to elevate to app-level environment — it's view-scoped, not shared between screens.

---

## Sources

### Primary (HIGH confidence)
- `developer.apple.com/documentation/swiftui/viewmodifier` — ViewModifier protocol conformance
- `developer.apple.com/documentation/swiftui/view/rotation3deffect` — rotation3DEffect parameters
- `developer.apple.com/tutorials/swiftui/drawing-paths-and-shapes` — Path API
- `createwithswift.com/using-core-motion-within-a-swiftui-application/` — CMMotionManager in SwiftUI (fetched directly)
- `hackingwithswift.com/articles/253/how-to-use-inner-shadows-to-simulate-depth-with-swiftui-and-core-motion` — CMMotionManager update interval, pitch/roll application (fetched directly)
- `swiftwithmajid.com/2023/10/10/sensory-feedback-in-swiftui/` — sensoryFeedback modifier API (fetched directly)
- `avanderlee.com/swift/appstorage-explained/` — @AppStorage Bool usage (fetched directly)
- `sarunw.com/posts/swiftui-custom-font/` — Custom font integration steps (fetched directly)
- `swiftbysundell.com/articles/defining-dynamic-colors-in-swift/` — Adaptive Color extensions (fetched directly)
- `fivestars.blog/articles/redacted-custom-effects/` — Custom redaction overlay pattern (fetched directly)
- `appcoda.com/swiftui-pie-chart/` — Path arc/slice drawing (fetched directly)

### Secondary (MEDIUM confidence)
- WebSearch results for Bebas Neue SIL OFL license — confirmed by multiple font distribution sites (github.com/dharmatype/Bebas-Neue, fontsquirrel.com/license/bebas-neue)
- WebSearch results for Space Grotesk SIL OFL license — confirmed by Font Squirrel and Google Fonts
- WebSearch results for SwiftUI spring animation parameters — cross-referenced with Apple docs

### Tertiary (LOW confidence)
- Specific pizza palette hex values — derived from neobrutalist design principles + pizza color intuition; should be validated in design review

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Apple-native APIs, verified via official documentation and direct page fetches
- Architecture: HIGH — ViewModifier pattern, @AppStorage, CMMotionManager patterns all verified with official/authoritative sources
- Font recommendations: MEDIUM — Bebas Neue and Space Grotesk confirmed OFL and appropriate aesthetically; PostScript names need in-Xcode verification
- Pitfalls: HIGH — derived from verified documentation of known API quirks (arc direction, font naming, Simulator CMMotion)
- Color palette values: LOW — specific hex values are educated recommendations, not validated in design tooling

**Research date:** 2026-02-21
**Valid until:** 2026-08-21 (stable APIs; SwiftUI and CoreMotion APIs unlikely to change materially in 6 months)
