import CoreLocation
@testable import TakeMeToPizza
import XCTest

final class PlaceTests: XCTestCase {

    // MARK: - Helpers

    private func makePlace(
        distanceMeters: Double = 500,
        name: String = "Test Pizza",
        lat: Double = 40.7308,
        lon: Double = -73.9892
    ) -> Place {
        Place(
            id: UUID(),
            name: name,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            address: "123 Test St",
            phoneNumber: "(555) 123-4567",
            websiteURL: URL(string: "https://example.com"),
            distanceMeters: distanceMeters
        )
    }

    // MARK: - Distance calculations

    func testDistanceInPizzaSlices() {
        let place = makePlace(distanceMeters: 203.2) // exactly 1000 slices
        XCTAssertEqual(place.distanceInPizzaSlices, 1000)
    }

    func testDistanceDisplayStringDefault() {
        let place = makePlace(distanceMeters: 203.2)
        XCTAssertEqual(place.distanceDisplayString, "1,000 slices away")
    }

    // MARK: - Unit-aware display strings

    func testDisplayStringPizzaSlices() {
        let place = makePlace(distanceMeters: 203.2)
        XCTAssertEqual(place.distanceDisplayString(for: .pizzaSlices), "1,000 slices away")
    }

    func testDisplayStringImperial() {
        let place = makePlace(distanceMeters: 100)
        let result = place.distanceDisplayString(for: .imperial)
        XCTAssertTrue(result.hasSuffix("ft away"))
    }

    func testDisplayStringMetric() {
        let place = makePlace(distanceMeters: 500)
        XCTAssertEqual(place.distanceDisplayString(for: .metric), "500 m away")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let original = makePlace()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Place.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.coordinate.latitude, original.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(decoded.coordinate.longitude, original.coordinate.longitude, accuracy: 0.0001)
        XCTAssertEqual(decoded.address, original.address)
        XCTAssertEqual(decoded.phoneNumber, original.phoneNumber)
        XCTAssertEqual(decoded.websiteURL, original.websiteURL)
        XCTAssertEqual(decoded.distanceMeters, original.distanceMeters, accuracy: 0.01)
    }

    func testCodableWithNilOptionals() throws {
        let place = Place(
            id: UUID(),
            name: "No Extras",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            address: "",
            phoneNumber: nil,
            websiteURL: nil,
            distanceMeters: 100
        )
        let data = try JSONEncoder().encode(place)
        let decoded = try JSONDecoder().decode(Place.self, from: data)

        XCTAssertNil(decoded.phoneNumber)
        XCTAssertNil(decoded.websiteURL)
    }

    // MARK: - withUpdatedDistance

    func testWithUpdatedDistance() {
        let place = makePlace(distanceMeters: 500, lat: 40.7308, lon: -73.9892)
        let newLocation = CLLocation(latitude: 40.7308, longitude: -73.9892)
        let updated = place.withUpdatedDistance(userLocation: newLocation)

        // Same coordinate as place — distance should be ~0
        XCTAssertEqual(updated.distanceMeters, 0, accuracy: 1)
        // Other properties should be preserved.
        XCTAssertEqual(updated.id, place.id)
        XCTAssertEqual(updated.name, place.name)
    }

    // MARK: - Equatable

    func testEquatableByID() {
        let id = UUID()
        let place1 = Place(
            id: id,
            name: "A",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            address: "",
            phoneNumber: nil,
            websiteURL: nil,
            distanceMeters: 100
        )
        let place2 = Place(
            id: id,
            name: "B",
            coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1),
            address: "different",
            phoneNumber: "555",
            websiteURL: nil,
            distanceMeters: 999
        )
        XCTAssertEqual(place1, place2, "Places with same ID should be equal")
    }

    func testNotEqualDifferentID() {
        let place1 = makePlace()
        let place2 = makePlace()
        XCTAssertNotEqual(place1, place2)
    }
}
