import SwiftUI

// MARK: - OnboardingView

/// Single-screen onboarding shown to first-time users only.
/// Gated in ContentView via @AppStorage(AppStorageKey.hasCompletedOnboarding).
/// Almost wordless -- the pizza slice carries the message.
struct OnboardingView: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sliceScale: CGFloat = 0.5

    var body: some View {
        ZStack {
            Color.pizzaBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                PizzaSliceShape()
                    .fill(Color.pizzaOrange)
                    .frame(width: 160, height: 160)
                    .scaleEffect(sliceScale)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.65),
                        value: sliceScale
                    )
                    .onAppear { sliceScale = 1.0 }

                Text("FOLLOW THE PIZZA")
                    .font(.pizzaDisplay(size: 36))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                Text("Your compass to the nearest slice")
                    .font(.pizzaBody(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                Button {
                    onComplete()
                } label: {
                    Text("LET'S GO")
                        .font(.pizzaDisplay(size: 20))
                }
                .buttonStyle(BrutalistPressStyle())
                .brutalistButton()
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}
