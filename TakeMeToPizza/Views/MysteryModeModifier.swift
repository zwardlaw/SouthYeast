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
/// A 360° spin toggles mystery mode, swapping the emoji at the midpoint.
struct MysteryToggleCard: View {
    let cardWidth: CGFloat
    @Binding var spinTrigger: Bool

    @AppStorage(AppStorageKey.mysteryMode) private var mysteryModeEnabled: Bool = false
    @State private var spinAngle: Double = 0

    var body: some View {
        Text(mysteryModeEnabled ? "😊" : "🫣")
            .font(.system(size: 36))
            .rotation3DEffect(.degrees(spinAngle), axis: (x: 0, y: 1, z: 0))
        .frame(width: cardWidth)
        .sensoryFeedback(.selection, trigger: mysteryModeEnabled)
        .onChange(of: spinTrigger) {
            // Full 360° Y-axis spin.
            withAnimation(.easeInOut(duration: 0.6)) {
                spinAngle += 360
            }
            // Swap emoji at the midpoint (view is edge-on, hides the switch).
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                mysteryModeEnabled.toggle()
            }
        }
    }
}
