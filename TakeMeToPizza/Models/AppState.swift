import CoreLocation
import Observation

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
/// - `isAligned` is true when needle is within 5 degrees of target AND the
///   2-second haptic cooldown has elapsed since last alignment event.
@Observable
@MainActor
final class AppState {
    var selectedPlace: Place?

    // Accumulated rotation -- NEVER clamped to 0-360.
    // Provides continuous angle value for SwiftUI spring animation.
    private(set) var compassAngle: Double = 0.0
    private var previousRawAngle: Double = 0.0

    // MARK: - Alignment Detection

    private var lastAlignmentTime: Date = .distantPast
    private let alignmentCooldown: TimeInterval = 2.0
    private var wasAligned = false

    /// True when the compass needle is within 5 degrees of pointing at the
    /// selected place AND the 2-second haptic cooldown has elapsed.
    /// Used by CompassView as a `.sensoryFeedback` trigger.
    var isAligned: Bool {
        let raw = (previousRawAngle.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        return abs(raw) < 5 && Date().timeIntervalSince(lastAlignmentTime) > alignmentCooldown
    }

    // MARK: - Dependencies

    private let locationService: LocationService
    private let placesService: PlacesService

    init(locationService: LocationService, placesService: PlacesService) {
        self.locationService = locationService
        self.placesService = placesService
        self.selectedPlace = placesService.places.first
    }

    /// Call whenever heading or selectedPlace changes.
    /// Computes accumulated compass angle using shortest-arc delta.
    /// Tracks alignment transitions and resets haptic cooldown when newly aligned.
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

        // Update haptic cooldown when alignment transitions from false -> true.
        let nowAligned = isAligned
        if nowAligned && !wasAligned {
            lastAlignmentTime = Date()
        }
        wasAligned = nowAligned
    }

    /// When true, user has dismissed the calibration overlay manually.
    var calibrationSkipped = false

    /// True when heading data is unreliable and calibration UI should be shown.
    var isCalibrating: Bool {
        locationService.headingAccuracy < 0 && !calibrationSkipped
    }
}
