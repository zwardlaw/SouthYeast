import SwiftUI

struct CompassView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    /// MotionService is view-scoped (not app-level environment) -- it only runs
    /// when CompassView is visible. Battery-safe: start/stop with appearance.
    @State private var motionService = MotionService()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Pizza-tinted background
            Color.pizzaBackground
                .ignoresSafeArea()

            // Full-screen compass content centered behind the carousel.
            VStack(spacing: 32) {
                if appState.isCalibrating {
                    // Calibration state -- heading data unreliable
                    VStack(spacing: 16) {
                        Image(systemName: "location.slash.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.pizzaOrange)
                        Text("Calibrating...")
                            .font(.pizzaDisplay(size: 20))
                        Text("Move your phone in a figure-eight pattern")
                            .font(.pizzaBody(size: 14))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Pizza slice needle -- rotates to point at the nearest pizza place.
                    // rotation3DEffect on the needle itself creates the tilt parallax.
                    PizzaSliceNeedle(motionService: motionService, isAligned: appState.isAligned)
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(appState.compassAngle))
                        .animation(
                            .interpolatingSpring(stiffness: 170, damping: 26),
                            value: appState.compassAngle
                        )
                        .sensoryFeedback(
                            .impact(flexibility: .rigid, intensity: 0.7),
                            trigger: appState.isAligned
                        )
                        .onAppear { motionService.start() }
                        .onDisappear { motionService.stop() }
                }

                // Target name -- shown above the carousel.
                if let place = appState.selectedPlace {
                    Text(place.name)
                        .font(.pizzaDisplay(size: 24))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Carousel overlay pinned to the bottom of the screen.
            CarouselView()
                .padding(.horizontal, 0)
                .padding(.bottom, 16)
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if !appState.isCalibrating { motionService.start() }
            case .background:
                motionService.stop()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
