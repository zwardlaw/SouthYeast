# Phase 3: Design and Personality - Context

**Gathered:** 2026-02-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Transform the functional compass app into the bold, physical, surprising experience that is Take Me to Pizza. Apply the neobrutalist design system (thick borders, hard shadows, bold typography, pizza palette) to every screen, replace the generic compass arrow with a custom pizza slice needle, add mystery mode as a hidden feature, and create a minimal onboarding + location priming flow. Mechanics are already correct from Phases 1-2 — this phase is pure visual identity and personality.

</domain>

<decisions>
## Implementation Decisions

### Visual identity
- Soft brutalist intensity — 2-3px borders, subtle shadows, bold but approachable (fun, not aggressive)
- Pizza warm color palette — reds, oranges, golden yellows (pepperoni and cheese vibes)
- Two custom fonts — a display/header typeface + a complementary body font for full typographic identity
- Both light and dark mode — dark mode gets a deep, warm treatment of the pizza palette

### Pizza slice needle
- Illustrated 2D slice with perspective tilt — detailed flat slice (cheese, crust, pepperoni) that responds to phone tilt angle via device motion, creating a fake 3D depth effect that feels like a physical instrument
- Prominent size — roughly 40-50% of the screen, clearly the hero element with room for cards below
- Alignment feedback: glow + pulse when pointed at target (Claude's discretion on exact treatment), with aspiration toward a "cooked when facing / cold when facing away" visual temperature concept if feasible within the design system
- AR camera passthrough with floating 3D pizza — deferred to future phase (requires ARKit, camera permissions, SceneKit)

### Mystery mode
- Activation: hidden by default — swipe right past the first card in the carousel to reveal the mystery mode toggle (unlabeled icon, just an emoji)
- Visual treatment: playful redaction — names get blacked-out redaction bars like a classified document
- Scope of hiding: everything except distance is redacted (name, address, phone all hidden) — you truly just follow the compass
- Persistence: mystery mode state persists across app launches via UserDefaults — stays on until explicitly toggled off

### Onboarding & priming
- Single onboarding screen — one illustration + one line explaining the compass concept, tap to start
- Minimal and direct tone — visual-first, almost no copy, let the pizza slice illustration do the talking
- Location priming: playful personality — illustration of pizza slice lost without location, warm/funny reason to grant permission
- Mystery mode is NOT mentioned in onboarding — pure easter egg, discovered organically by swiping right

### Claude's Discretion
- Exact border widths, shadow offsets, and corner radii within the soft brutalist range
- Specific custom font selections (display + body)
- Loading skeleton design and error state visual treatment
- Exact spring animation parameters and haptic patterns
- Perspective tilt implementation approach (SceneKit vs SwiftUI 3D transforms)
- How to render the "cooked vs cold" temperature concept if feasible, or fall back to glow + pulse

</decisions>

<specifics>
## Specific Ideas

- "I want a fully 3D slice of pizza floating in 3D space locked to point at the pizza place and parallel to the ground" — the dream is AR with camera passthrough for shareable screenshots of pizza floating in front of real pizza shops. For this phase: 2D illustrated slice with perspective tilt as a step toward that vision.
- "The pizza gets nicely cooked when you're facing toward it and cold when you're facing away" — visual temperature feedback based on alignment angle. Aspirational for this phase, glow/pulse as fallback.
- Mystery mode should feel like a classified document — redaction bars, not just question marks.
- Onboarding should be almost wordless — the pizza slice illustration carries the message.

</specifics>

<deferred>
## Deferred Ideas

- Full AR mode with camera passthrough — 3D pizza slice floating in real space via ARKit/SceneKit, shareable screenshots of pizza pointing at real pizza shops. Major new capability requiring camera permissions and AR framework.

</deferred>

---

*Phase: 03-design-and-personality*
*Context gathered: 2026-02-21*
