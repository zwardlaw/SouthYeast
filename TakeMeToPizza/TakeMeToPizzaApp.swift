import SwiftUI
import CoreLocation

@main
struct TakeMeToPizzaApp: App {
    // Declared without default values -- initialized only in init() via State(initialValue:).
    // This ensures single allocation of each service (no double-init discard).
    @State private var locationService: LocationService
    @State private var placesService: PlacesService
    @State private var appState: AppState
    @State private var networkMonitor: NetworkMonitor

    init() {
        #if DEBUG
        let isDemo = CommandLine.arguments.contains("--demo-mode")
        #else
        let isDemo = false
        #endif

        let loc = LocationService(demoMode: isDemo)
        let places = PlacesService()
        let state = AppState(locationService: loc, placesService: places)

        #if DEBUG
        if isDemo {
            // Pre-populate services with deterministic data for screenshots.
            loc.authorizationStatus = .authorizedWhenInUse
            loc.location = CLLocation(latitude: 40.7306, longitude: -73.9866)
            loc.heading = 45.0
            loc.headingAccuracy = 10.0
            places.places = Place.samplePlaces
            state.selectedPlace = Place.samplePlaces.first
            state.calibrationSkipped = true
            state.updateCompassAngle()

            UserDefaults.standard.set(true, forKey: AppStorageKey.hasCompletedOnboarding)
            UserDefaults.standard.set(DistanceUnit.pizzaSlices.rawValue, forKey: AppStorageKey.distanceUnit)
            UserDefaults.standard.set("apple", forKey: AppStorageKey.preferredMapsApp)

            if CommandLine.arguments.contains("--mystery-mode") {
                UserDefaults.standard.set(true, forKey: AppStorageKey.mysteryMode)
            } else {
                UserDefaults.standard.set(false, forKey: AppStorageKey.mysteryMode)
            }
        }
        #endif

        _locationService = State(initialValue: loc)
        _placesService = State(initialValue: places)
        _appState = State(initialValue: state)
        _networkMonitor = State(initialValue: NetworkMonitor())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationService)
                .environment(placesService)
                .environment(appState)
                .environment(networkMonitor)
        }
    }
}

#Preview {
    let location = LocationService()
    let places = PlacesService()
    let state = AppState(locationService: location, placesService: places)
    ContentView()
        .environment(location)
        .environment(places)
        .environment(state)
}
