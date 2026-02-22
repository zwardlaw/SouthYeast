import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(LocationService.self) private var locationService
    @Environment(AppState.self) private var appState
    @Environment(PlacesService.self) private var placesService

    @AppStorage(AppStorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding: Bool = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(onComplete: { hasCompletedOnboarding = true })
            } else {
                switch locationService.permissionStatus {
                case .notDetermined:
                    PermissionPrimingView()
                case .denied:
                    PermissionDeniedView()
                case .restricted:
                    PermissionRestrictedView()
                case .authorized:
                    CompassView()
                        .task {
                            // Trigger initial fetch if location is already available
                            // when the view appears (e.g., after permission was already granted).
                            if let location = locationService.location,
                               placesService.places.isEmpty {
                                await placesService.fetchNearby(userLocation: location)
                                if appState.selectedPlace == nil {
                                    appState.selectedPlace = placesService.places.first
                                    appState.updateCompassAngle()
                                }
                            }
                        }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                locationService.startUpdating()
            case .background:
                locationService.stopUpdating()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onChange(of: locationService.heading) { _, _ in
            appState.updateCompassAngle()
        }
        .onChange(of: appState.selectedPlace) { _, _ in
            appState.updateCompassAngle()
        }
        .onChange(of: locationService.location) { _, newLocation in
            guard let location = newLocation else { return }
            if placesService.places.isEmpty {
                // Initial fetch -- places not yet loaded.
                Task {
                    await placesService.fetchNearby(userLocation: location)
                    // Set selectedPlace to nearest after first fetch.
                    if appState.selectedPlace == nil {
                        appState.selectedPlace = placesService.places.first
                        appState.updateCompassAngle()
                    }
                }
            } else {
                // Subsequent movement -- update distances only (no new MKLocalSearch).
                // LocationService.distanceFilter = 50m, so this fires every 50m of movement.
                placesService.updateDistances(userLocation: location)
                appState.updateCompassAngle()
            }
        }
    }
}

// MARK: - Permission Views

/// Custom pre-prompt shown before the iOS system location dialog.
/// Explains the app's purpose and asks for permission explicitly.
struct PermissionPrimingView: View {
    @Environment(LocationService.self) private var locationService

    @State private var wiggle: Bool = false

    var body: some View {
        ZStack {
            Color.pizzaBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                PizzaSliceShape()
                    .fill(Color.pizzaOrange)
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(wiggle ? 8 : -8))
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: wiggle
                    )
                    .onAppear { wiggle = true }

                Text("FOLLOW THE PIZZA")
                    .font(.pizzaDisplay(size: 32))
                    .multilineTextAlignment(.center)

                Text("This little pizza slice is lost without you. Share your location so it can point you to the nearest pizza.")
                    .font(.pizzaBody(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)

                Spacer()

                Button {
                    locationService.startUpdating()
                } label: {
                    Text("LET'S FIND PIZZA")
                        .font(.pizzaDisplay(size: 18))
                }
                .brutalistButton()
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

/// Shown when the user has explicitly denied location access.
/// Directs them to Settings to re-enable.
struct PermissionDeniedView: View {
    var body: some View {
        ZStack {
            Color.pizzaBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                PizzaSliceShape()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(180))

                Text("PIZZA SLICE IS SAD")
                    .font(.pizzaDisplay(size: 28))
                    .multilineTextAlignment(.center)

                Text("The pizza slice can't find pizza without your location. You can fix this in Settings.")
                    .font(.pizzaBody(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)

                Spacer()

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("OPEN SETTINGS")
                        .font(.pizzaDisplay(size: 18))
                }
                .brutalistButton()
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

/// Shown when location access is restricted by parental controls or MDM policy.
struct PermissionRestrictedView: View {
    var body: some View {
        ZStack {
            Color.pizzaBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.pizzaOrange)

                Text("LOCATION RESTRICTED")
                    .font(.pizzaDisplay(size: 28))
                    .multilineTextAlignment(.center)

                Text("Location access is restricted on this device. Contact your device administrator to enable it.")
                    .font(.pizzaBody(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)

                Spacer()
            }
        }
    }
}
