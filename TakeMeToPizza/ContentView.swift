import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(LocationService.self) private var locationService
    @Environment(AppState.self) private var appState
    @Environment(PlacesService.self) private var placesService

    var body: some View {
        Group {
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
/// Phase 3 adds neobrutalist styling.
struct PermissionPrimingView: View {
    @Environment(LocationService.self) private var locationService

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)

            Text("Find Nearby Pizza")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Take Me to Pizza needs your location to find nearby pizza and point you to it.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Button {
                locationService.startUpdating()
            } label: {
                Text("Find Pizza")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
        }
    }
}

/// Shown when the user has explicitly denied location access.
/// Directs them to Settings to re-enable.
struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Text("Location Denied")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Take Me to Pizza needs location access to find nearby pizza. Enable it in Settings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
        }
    }
}

/// Shown when location access is restricted by parental controls or MDM policy.
struct PermissionRestrictedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Text("Location Restricted")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Location access is restricted on this device. Contact your device administrator to enable it.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
    }
}
