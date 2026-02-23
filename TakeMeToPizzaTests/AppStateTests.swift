import XCTest
import CoreLocation
@testable import TakeMeToPizza

@MainActor
final class AppStateTests: XCTestCase {

    // MARK: - Helpers

    private func makeServices() -> (LocationService, PlacesService) {
        let location = LocationService()
        let places = PlacesService()
        return (location, places)
    }

    private func makePlace(lat: Double = 40.7308, lon: Double = -73.9892) -> Place {
        Place(
            id: UUID(),
            name: "Test Pizza",
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            address: "123 Test St",
            phoneNumber: nil,
            websiteURL: nil,
            distanceMeters: 500
        )
    }

    // MARK: - Initial state

    func testInitialCompassAngle() {
        let (location, places) = makeServices()
        let state = AppState(locationService: location, placesService: places)
        XCTAssertEqual(state.compassAngle, 0.0)
    }

    func testInitialSelectedPlaceNil() {
        let (location, places) = makeServices()
        let state = AppState(locationService: location, placesService: places)
        XCTAssertNil(state.selectedPlace)
    }

    func testInitialSelectedPlaceFromPlaces() {
        let (location, places) = makeServices()
        let place = makePlace()
        places.places = [place]
        let state = AppState(locationService: location, placesService: places)
        XCTAssertEqual(state.selectedPlace?.id, place.id)
    }

    // MARK: - Calibration

    func testIsCalibrating() {
        let (location, places) = makeServices()
        let state = AppState(locationService: location, placesService: places)
        // Default headingAccuracy is -1 → calibrating.
        XCTAssertTrue(state.isCalibrating)
    }

    func testCalibrationSkipped() {
        let (location, places) = makeServices()
        let state = AppState(locationService: location, placesService: places)
        state.calibrationSkipped = true
        XCTAssertFalse(state.isCalibrating)
    }

    // MARK: - Compass angle update

    func testUpdateCompassAngleNoOp() {
        let (location, places) = makeServices()
        let state = AppState(locationService: location, placesService: places)
        // No selected place — angle should stay 0.
        state.updateCompassAngle()
        XCTAssertEqual(state.compassAngle, 0.0)
    }

    // MARK: - Alignment detection

    func testIsAlignedInitiallyTrue() {
        // previousRawAngle starts at 0 (within 5° threshold) and
        // lastAlignmentTime is .distantPast (past cooldown), so isAligned is true.
        let (location, places) = makeServices()
        let state = AppState(locationService: location, placesService: places)
        XCTAssertTrue(state.isAligned)
    }
}
