import CoreLocation
import Foundation
import Observation

// MARK: - PermissionStatus

enum PermissionStatus {
    case notDetermined
    case denied
    case restricted
    case authorized
}

// MARK: - LocationService

/// @Observable CLLocationManager wrapper with full permission state machine.
/// Publishes heading, location, and headingAccuracy to SwiftUI views.
///
/// Critical correctness rules enforced here:
/// - Only trueHeading is used (requires startUpdatingLocation running simultaneously).
/// - Heading updates are gated on headingAccuracy >= 0 — invalid readings are ignored.
/// - headingAccuracy defaults to -1.0 so the app starts in calibration state.
/// - CLHeading is NOT Sendable — scalar Doubles are extracted before Task boundaries.
@Observable
@MainActor
final class LocationService: NSObject {

    // MARK: Published Properties

    var location: CLLocation?
    var heading: Double = 0.0
    var headingAccuracy: Double = -1.0
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// When true, startUpdating/stopUpdating are no-ops. Used in demo mode
    /// to prevent CLLocationManager from triggering the system permission prompt.
    var isDemoMode = false

    // MARK: Computed

    var permissionStatus: PermissionStatus {
        switch authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .authorizedWhenInUse, .authorizedAlways:
            return .authorized
        @unknown default:
            return .denied
        }
    }

    // MARK: Private

    private let manager: CLLocationManager

    // MARK: Init

    init(demoMode: Bool = false) {
        self.isDemoMode = demoMode
        manager = CLLocationManager()
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 50.0
        manager.headingFilter = 1.0
        manager.delegate = self
    }

    // MARK: Public API

    func startUpdating() {
        if isDemoMode { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        default:
            break
        }
    }

    func stopUpdating() {
        if isDemoMode { return }
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        // Reset to -1 so calibration overlay appears on next resume.
        headingAccuracy = -1.0
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if self.isDemoMode { return }
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
                self.manager.startUpdatingHeading()
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        // CLLocation is Sendable — safe to capture across actor boundary.
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.location = latest
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateHeading newHeading: CLHeading
    ) {
        // CLHeading is NOT Sendable — extract scalars before crossing the actor boundary.
        let trueHeading = newHeading.trueHeading
        let accuracy = newHeading.headingAccuracy
        Task { @MainActor in
            self.headingAccuracy = accuracy
            // Only update heading when accuracy is valid (>= 0).
            if accuracy >= 0 {
                self.heading = trueHeading
            }
        }
    }

    nonisolated func locationManagerShouldDisplayHeadingCalibration(
        _ manager: CLLocationManager
    ) -> Bool {
        return true
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Ignored — location errors are non-fatal. The UI shows appropriate
        // empty/error states via PlacesService and NetworkMonitor.
    }
}
