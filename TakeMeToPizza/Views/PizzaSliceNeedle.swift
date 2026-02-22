import SwiftUI

// MARK: - PizzaSliceShape

/// Simple triangle with tip pointing up (12 o'clock).
/// Placeholder shape — will be replaced with a custom pizza illustration.
struct PizzaSliceShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))           // tip (top center)
        path.addLine(to: CGPoint(x: rect.maxX * 0.82, y: rect.maxY)) // bottom right
        path.addLine(to: CGPoint(x: rect.maxX * 0.18, y: rect.maxY)) // bottom left
        path.closeSubpath()
        return path
    }
}

// MARK: - PizzaSliceNeedle

/// The compass needle — a simple triangle with tilt parallax and alignment glow.
/// The triangle tip points toward the target pizza place.
struct PizzaSliceNeedle: View {
    let motionService: MotionService
    let isAligned: Bool

    var body: some View {
        PizzaSliceShape()
            .fill(Color.pizzaOrange)
            .overlay(
                PizzaSliceShape()
                    .stroke(Color.primary, lineWidth: 2)
            )
            .shadow(
                color: Color.pizzaGold.opacity(isAligned ? 0.75 : 0),
                radius: 14
            )
            .animation(.easeInOut(duration: 0.3), value: isAligned)
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

// MARK: - CurvedText

/// Renders text along a circular arc centered at 12 o'clock (above center).
/// Used for the target place name that rotates with the compass needle.
/// When the compass points away from the user, the text appears upside down.
struct CurvedText: View {
    let text: String
    let radius: CGFloat
    var fontSize: CGFloat = 20

    var body: some View {
        ZStack {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(.pizzaDisplay(size: fontSize))
                    .offset(y: -radius)
                    .rotationEffect(characterAngle(at: index))
            }
        }
    }

    private func characterAngle(at index: Int) -> Angle {
        let spacing: Double = 7.5 // degrees between character centers
        let totalWidth = spacing * Double(text.count - 1)
        let startAngle = -totalWidth / 2
        return .degrees(startAngle + Double(index) * spacing)
    }
}
