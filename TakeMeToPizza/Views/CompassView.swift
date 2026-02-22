import SwiftUI

struct CompassView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen compass content centered behind the carousel.
            VStack(spacing: 32) {
                if appState.isCalibrating {
                    // Calibration state -- heading data unreliable
                    VStack(spacing: 16) {
                        Image(systemName: "location.slash.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Calibrating...")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Move your phone in a figure-eight pattern")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Phase 1 placeholder needle -- arrow pointing up, rotated by compass angle.
                    // Phase 3 replaces this with the custom pizza slice Shape.
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(.orange)
                        .rotationEffect(.degrees(appState.compassAngle))
                        .animation(
                            .interpolatingSpring(stiffness: 170, damping: 26),
                            value: appState.compassAngle
                        )
                        .sensoryFeedback(
                            .impact(flexibility: .rigid, intensity: 0.7),
                            trigger: appState.isAligned
                        )
                }

                // Target name -- shown above the carousel.
                if let place = appState.selectedPlace {
                    Text(place.name)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Carousel overlay pinned to the bottom of the screen.
            CarouselView()
                .padding(.horizontal, 0)
                .padding(.bottom, 16)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
