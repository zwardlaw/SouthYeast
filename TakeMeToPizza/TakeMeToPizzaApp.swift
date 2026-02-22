import SwiftUI

@main
struct TakeMeToPizzaApp: App {
    // Declared without default values -- initialized only in init() via State(initialValue:).
    // This ensures single allocation of each service (no double-init discard).
    @State private var locationService: LocationService
    @State private var placesService: PlacesService
    @State private var appState: AppState
    @State private var networkMonitor: NetworkMonitor

    init() {
        let loc = LocationService()
        let places = PlacesService()
        let state = AppState(locationService: loc, placesService: places)
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
