import SwiftUI

// MARK: - MysteryRedacted ViewModifier

/// Overlays a solid black bar (classified-document style) over content
/// when mystery mode is active. Uses a solid fill, not SwiftUI's built-in
/// `.redacted(reason: .placeholder)` which renders a gray shimmer instead.
struct MysteryRedacted: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.primary)
                            .padding(.vertical, 2)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isActive)
            )
    }
}

// MARK: - View Extension

extension View {
    /// Applies a classified-document redaction bar when `isActive` is true.
    /// Distance is never redacted -- only names, addresses, phone, and website.
    func mysteryRedacted(isActive: Bool) -> some View {
        modifier(MysteryRedacted(isActive: isActive))
    }
}

// MARK: - MysteryToggleCard

/// The leftmost carousel card that reveals mystery mode.
/// Discovered organically by swiping right past the first place card.
/// Tapping toggles the mystery mode on/off with haptic feedback.
struct MysteryToggleCard: View {
    let cardWidth: CGFloat

    @AppStorage(AppStorageKey.mysteryMode) private var mysteryModeEnabled: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            Text("🫣")
                .font(.system(size: 48))

            if mysteryModeEnabled {
                Text("MYSTERY ON")
                    .font(.pizzaBody(size: 12))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.pizzaOrange)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .brutalistCard()
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                mysteryModeEnabled.toggle()
            }
        }
        .sensoryFeedback(.selection, trigger: mysteryModeEnabled)
    }
}
