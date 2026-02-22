import SwiftUI

// MARK: - Brutalist Card Modifier

/// Gumroad-style neobrutalist card: white background, black border, hard black drop shadow.
struct BrutalistCard: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(Color.pizzaCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black)
                    .offset(x: 4, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.primary, lineWidth: 1.5)
            )
    }
}

// MARK: - Brutalist Button Modifier

/// Full-width action button with Bebas Neue lettering and hard black shadow.
struct BrutalistButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.pizzaDisplay(size: 18))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.pizzaRed)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .offset(x: 4, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary, lineWidth: 1.5)
            )
    }
}

// MARK: - Brutalist Button Style

/// Provides press-down scale + haptic feedback on tap for brutalist buttons.
struct BrutalistPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply neobrutalist card styling with an optional custom corner radius.
    func brutalistCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(BrutalistCard(cornerRadius: cornerRadius))
    }

    /// Apply neobrutalist full-width button styling.
    func brutalistButton() -> some View {
        modifier(BrutalistButton())
    }
}
