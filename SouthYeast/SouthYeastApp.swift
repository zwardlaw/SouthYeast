import SwiftUI

@main
struct SouthYeastApp: App {
    // Declared without default values -- initialized only in init() via State(initialValue:).
    // This ensures single allocation of each service (no double-init discard).
    @State private var locationService: LocationService
    @State private var placesService: PlacesService
    @State private var appState: AppState

    init() {
        let loc = LocationService()
        let places = PlacesService()
        let state = AppState(locationService: loc, placesService: places)
        _locationService = State(initialValue: loc)
        _placesService = State(initialValue: places)
        _appState = State(initialValue: state)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationService)
                .environment(placesService)
                .environment(appState)
        }
    }
}
