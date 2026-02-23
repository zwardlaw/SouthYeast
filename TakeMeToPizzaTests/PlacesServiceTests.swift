import XCTest
import CoreLocation
@testable import TakeMeToPizza

@MainActor
final class PlacesServiceTests: XCTestCase {

    // MARK: - Initial state

    func testInitialState() {
        let service = PlacesService()
        XCTAssertTrue(service.places.isEmpty)
        XCTAssertFalse(service.isLoading)
        XCTAssertNil(service.error)
    }

    // MARK: - Update distances

    func testUpdateDistancesSorting() {
        let service = PlacesService()

        // Create places at known coordinates.
        let farPlace = Place(
            id: UUID(),
            name: "Far Pizza",
            coordinate: CLLocationCoordinate2D(latitude: 40.8, longitude: -73.9),
            address: "Far away",
            phoneNumber: nil,
            websiteURL: nil,
            distanceMeters: 1000
        )
        let nearPlace = Place(
            id: UUID(),
            name: "Near Pizza",
            coordinate: CLLocationCoordinate2D(latitude: 40.7309, longitude: -73.9892),
            address: "Right here",
            phoneNumber: nil,
            websiteURL: nil,
            distanceMeters: 50
        )

        // Set places with far first.
        service.places = [farPlace, nearPlace]

        // Update distances from a location near the nearPlace.
        let userLocation = CLLocation(latitude: 40.7308, longitude: -73.9892)
        service.updateDistances(userLocation: userLocation)

        // After update, places should be sorted by distance — near first.
        XCTAssertEqual(service.places.count, 2)
        XCTAssertEqual(service.places.first?.id, nearPlace.id)
    }

    func testUpdateDistancesRecalculates() {
        let service = PlacesService()

        let place = Place(
            id: UUID(),
            name: "Test Pizza",
            coordinate: CLLocationCoordinate2D(latitude: 40.7308, longitude: -73.9892),
            address: "Test",
            phoneNumber: nil,
            websiteURL: nil,
            distanceMeters: 9999 // Intentionally wrong
        )

        service.places = [place]

        // Update from the exact coordinate — distance should become ~0.
        let userLocation = CLLocation(latitude: 40.7308, longitude: -73.9892)
        service.updateDistances(userLocation: userLocation)

        XCTAssertEqual(service.places.first?.distanceMeters ?? 9999, 0, accuracy: 1)
    }
}
