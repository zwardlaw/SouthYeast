import SwiftUI

// MARK: - Brutalist Card Modifier

/// Applies Gumroad-style neobrutalist card appearance:
/// solid background, single clean border, hard offset shadow.
struct BrutalistCard: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(Color.pizzaCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.primary, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 0, x: 3, y: 3)
    }
}

// MARK: - Brutalist Button Modifier

/// Full-width action button with Bebas Neue lettering and hard offset shadow.
struct BrutalistButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.pizzaDisplay(size: 18))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.pizzaRed)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 0, x: 3, y: 3)
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
