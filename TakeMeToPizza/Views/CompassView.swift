import SwiftUI

struct CompassView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationService.self) private var locationService
    @Environment(\.scenePhase) private var scenePhase

    /// MotionService is view-scoped (not app-level environment) -- it only runs
    /// when CompassView is visible. Battery-safe: start/stop with appearance.
    @AppStorage(AppStorageKey.mysteryMode) private var mysteryModeEnabled: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motionService = MotionService()
    @State private var showSettings = false

    private var compassAccessibilityLabel: String {
        guard let place = appState.selectedPlace else { return "Pizza compass" }
        let name = mysteryModeEnabled ? "a mystery pizza place" : place.name
        let aligned = appState.isAligned ? "You are facing it." : "Turn to follow the needle."
        return "Compass pointing to \(name), \(place.distanceDisplayString). \(aligned)"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Pizza-tinted background
            Color.pizzaBackground
                .ignoresSafeArea()

            // Full-screen compass content centered behind the carousel.
            VStack {
                Spacer()

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
                    // Compass assembly: needle + curved place name rotate together.
                    // The name sits on a circular arc at the tip of the needle.
                    // When facing away from the target, the name appears upside down.
                    ZStack {
                        PizzaSliceNeedle(motionService: motionService, isAligned: appState.isAligned)
                            .frame(width: 140, height: 140)

                        if let place = appState.selectedPlace {
                            CurvedText(
                                text: mysteryModeEnabled ? "PIZZA" : place.name.uppercased(),
                                radius: 110,
                                fontSize: 20
                            )
                        }
                    }
                    .rotationEffect(.degrees(appState.compassAngle))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(compassAccessibilityLabel)
                    .animation(
                        reduceMotion ? .none : .interpolatingSpring(stiffness: 170, damping: 26),
                        value: appState.compassAngle
                    )
                    .sensoryFeedback(
                        .impact(flexibility: .rigid, intensity: 0.7),
                        trigger: appState.isAligned
                    )
                    .onAppear { motionService.start() }
                    .onDisappear { motionService.stop() }
                }

                Spacer()
                // Reserve space for the carousel overlay below.
                Spacer().frame(height: 160)
            }
            .frame(maxWidth: .infinity)

            // GPS accuracy warning — shown when horizontal error exceeds 100m.
            if let accuracy = locationService.location?.horizontalAccuracy,
               accuracy > 100 {
                Text("GPS signal weak — compass may be inaccurate")
                    .font(.pizzaBody(size: 12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.pizzaRed.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.bottom, 160)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityLabel("GPS signal is weak, compass may be inaccurate")
            }

            // Carousel overlay pinned to the bottom of the screen.
            CarouselView()
                .padding(.horizontal, 0)
                .padding(.bottom, 16)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.primary)
                    .padding(12)
            }
            .accessibilityLabel("Settings")
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
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

#if DEBUG
#Preview {
    let location = LocationService()
    let places = PlacesService()
    places.places = Place.samplePlaces
    let state = AppState(locationService: location, placesService: places)
    state.selectedPlace = Place.samplePlaces.first
    let network = NetworkMonitor()
    return CompassView()
        .environment(location)
        .environment(places)
        .environment(state)
        .environment(network)
}
#endif
