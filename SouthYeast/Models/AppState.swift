import Observation
import CoreLocation

/// Central app state that wires LocationService and PlacesService into a
/// compass angle value safe to render in SwiftUI.
///
/// Key correctness rules:
/// - `compassAngle` is accumulated (adds deltas), NEVER clamped to 0-360.
///   This prevents full-circle spin when the needle crosses the north boundary.
/// - `rawAngle = bearing - heading` subtracts device heading so the needle
///   tracks phone rotation (points to target, not just geographic direction).
/// - `normalizeAngleDelta` ensures shortest-arc delta (no 358-degree spins).
/// - Guard on `headingAccuracy >= 0` suppresses updates when uncalibrated.
@Observable
@MainActor
final class AppState {
    var selectedPlace: Place?

    // Accumulated rotation -- NEVER clamped to 0-360.
    // Provides continuous angle value for SwiftUI spring animation.
    private(set) var compassAngle: Double = 0.0
    private var previousRawAngle: Double = 0.0

    private let locationService: LocationService
    private let placesService: PlacesService

    init(locationService: LocationService, placesService: PlacesService) {
        self.locationService = locationService
        self.placesService = placesService
        self.selectedPlace = placesService.places.first
    }

    /// Call whenever heading or selectedPlace changes.
    /// Computes accumulated compass angle using shortest-arc delta.
    func updateCompassAngle() {
        guard let place = selectedPlace,
              let location = locationService.location,
              locationService.headingAccuracy >= 0 else {
            return  // Invalid state — view shows calibration overlay
        }
        let bear = bearing(from: location.coordinate, to: place.coordinate)
        let rawAngle = bear - locationService.heading
        let delta = normalizeAngleDelta(rawAngle - previousRawAngle)
        compassAngle += delta
        previousRawAngle = rawAngle
    }

    /// True when heading data is unreliable and calibration UI should be shown.
    var isCalibrating: Bool {
        locationService.headingAccuracy < 0
    }
}
