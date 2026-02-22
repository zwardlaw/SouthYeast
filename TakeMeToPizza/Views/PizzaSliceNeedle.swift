import SwiftUI

// MARK: - PizzaSliceShape

/// A pizza slice sector pointing upward (tip at center, crust arc at top).
/// Tip angle = -90 degrees (12 o'clock in SwiftUI's coord system where 0 = 3 o'clock).
/// Total arc width = 36 degrees (18 half-angle on each side).
struct PizzaSliceShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.45

        // Tip at 12 o'clock = -90 degrees; half-angle = 18 degrees.
        let tipAngleDeg: Double = -90
        let halfAngleDeg: Double = 18

        // Left and right crust edge angles in degrees.
        let leftAngleDeg  = tipAngleDeg - halfAngleDeg   // -108
        let rightAngleDeg = tipAngleDeg + halfAngleDeg   //  -72

        // Convert to radians for CGPoint arithmetic.
        let leftRad  = leftAngleDeg  * .pi / 180
        let rightRad = rightAngleDeg * .pi / 180

        // Points on the crust arc edge.
        let leftEdge  = CGPoint(x: center.x + radius * cos(leftRad),
                                y: center.y + radius * sin(leftRad))
        let rightEdge = CGPoint(x: center.x + radius * cos(rightRad),
                                y: center.y + radius * sin(rightRad))

        var path = Path()
        path.move(to: center)
        path.addLine(to: leftEdge)
        // Arc from left to right edge going clockwise visually (counter-clockwise in
        // SwiftUI's flipped Y coordinate system -- so clockwise: false).
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(leftAngleDeg),
            endAngle: .degrees(rightAngleDeg),
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
            let spots: [(CGFloat, CGFloat, CGFloat)] = [
                (cx,        cy - r * 0.55, 7),  // top center, near crust
                (cx - r * 0.18, cy - r * 0.3, 6),  // left of center
                (cx + r * 0.18, cy - r * 0.3, 6),  // right of center
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
