import SwiftUI

// MARK: - PizzaSliceShape

/// A pizza slice sector with the pointy tip at top (12 o'clock) and crust arc at bottom.
/// The tip points TOWARD the target when used as a compass needle.
/// Total arc width = 36 degrees (18 half-angle on each side).
struct PizzaSliceShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.45

        // Crust at 6 o'clock (+90 degrees) so the tip (at center) points UP.
        let crustAngleDeg: Double = 90
        let halfAngleDeg: Double = 18

        let startAngleDeg = crustAngleDeg - halfAngleDeg  // 72
        let endAngleDeg   = crustAngleDeg + halfAngleDeg  // 108

        let startRad = startAngleDeg * .pi / 180
        let startEdge = CGPoint(x: center.x + radius * CGFloat(cos(startRad)),
                                y: center.y + radius * CGFloat(sin(startRad)))

        var path = Path()
        path.move(to: center)
        path.addLine(to: startEdge)
        // Arc from start to end — clockwise: false in SwiftUI's flipped Y = clockwise on screen.
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngleDeg),
            endAngle: .degrees(endAngleDeg),
            clockwise: false
        )
        path.addLine(to: center)
        path.closeSubpath()
        return path
    }
}

// MARK: - PizzaSliceNeedle

/// The composed pizza slice compass needle.
///
/// Renders a pizza slice with cheese fill, crust stroke, and pepperoni dots.
/// Applies two `rotation3DEffect` passes for device-tilt parallax (requires MotionService).
/// Glows gold and pulses when `isAligned` is true.
struct PizzaSliceNeedle: View {
    let motionService: MotionService
    let isAligned: Bool

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // -- Base slice fill (cheese color, warmer when aligned) --
            PizzaSliceShape()
                .fill(
                    isAligned
                        ? Color.pizzaOrange
                        : Color.pizzaOrange.opacity(0.72)
                )
                .animation(.easeInOut(duration: 0.4), value: isAligned)

            // -- Crust arc stroke overlay --
            PizzaSliceShape()
                .stroke(Color.pizzaRed, lineWidth: 6)

            // -- Pepperoni dots --
            PepperoniOverlay()
        }
        // -- Alignment glow shadow --
        .shadow(
            color: Color.pizzaGold.opacity(isAligned ? 0.75 : 0),
            radius: 14
        )
        .animation(.easeInOut(duration: 0.3), value: isAligned)
        // -- Pulse ring when aligned --
        .overlay(
            Circle()
                .stroke(Color.pizzaGold, lineWidth: 2.5)
                .scaleEffect(isPulsing ? 1.6 : 1.0)
                .opacity(isPulsing ? 0 : (isAligned ? 0.85 : 0))
                .animation(
                    isAligned
                        ? .easeOut(duration: 0.8).repeatForever(autoreverses: false)
                        : .default,
                    value: isPulsing
                )
        )
        .onChange(of: isAligned) { _, aligned in
            isPulsing = false
            if aligned {
                // Small delay allows the animation to reset before restarting.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isPulsing = true
                }
            }
        }
        // -- Device tilt parallax (two axes) --
        .rotation3DEffect(
            .degrees(motionService.roll * 15),
            axis: (x: 0, y: 1, z: 0)
        )
        .rotation3DEffect(
            .degrees(motionService.pitch * 15),
            axis: (x: -1, y: 0, z: 0)
        )
    }
}

// MARK: - PepperoniOverlay

/// Three small filled circles at fixed positions on the slice face to suggest pepperoni.
private struct PepperoniOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let r  = min(geo.size.width, geo.size.height) * 0.45

            // Offset positions relative to slice center, placed within the slice area.
            // Crust is at bottom (+y), tip is at center, so pepperoni goes below center.
            let spots: [(CGFloat, CGFloat, CGFloat)] = [
                (cx,              cy + r * 0.55, 7),  // bottom center, near crust
                (cx - r * 0.18,  cy + r * 0.3,  6),  // left of center
                (cx + r * 0.18,  cy + r * 0.3,  6),  // right of center
            ]

            ZStack {
                ForEach(Array(spots.enumerated()), id: \.offset) { _, spot in
                    Circle()
                        .fill(Color.pizzaRed)
                        .frame(width: spot.2 * 2, height: spot.2 * 2)
                        .position(x: spot.0, y: spot.1)
                }
            }
        }
    }
}
