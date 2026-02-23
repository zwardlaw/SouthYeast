import XCTest
import CoreLocation
@testable import TakeMeToPizza

final class PlacesCacheTests: XCTestCase {

    private let testLocation = CLLocation(latitude: 40.7308, longitude: -73.9892)

    override func tearDown() {
        super.tearDown()
        PlacesCache.clear()
    }

    // MARK: - Helpers

    private func makePlaces(count: Int = 3) -> [Place] {
        (0..<count).map { i in
            Place(
                id: UUID(),
                name: "Pizza \(i)",
                coordinate: CLLocationCoordinate2D(
                    latitude: 40.7308 + Double(i) * 0.001,
                    longitude: -73.9892
                ),
                address: "\(i) Test St",
                phoneNumber: nil,
                websiteURL: nil,
                distanceMeters: Double(i + 1) * 100
            )
        }
    }

    // MARK: - Save / Load round-trip

    func testSaveAndLoadRoundTrip() {
        let places = makePlaces()
        PlacesCache.save(places: places, userLocation: testLocation)

        let loaded = PlacesCache.load(currentLocation: testLocation)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.count, places.count)
        // IDs should be preserved.
        XCTAssertEqual(loaded?.map(\.id), places.map(\.id))
    }

    // MARK: - TTL expiry

    func testExpiredCacheReturnsNil() {
        let places = makePlaces()
        PlacesCache.save(places: places, userLocation: testLocation)

        // Manually write an expired envelope.
        let envelope = ExpiredEnvelope(
            places: places,
            latitude: testLocation.coordinate.latitude,
            longitude: testLocation.coordinate.longitude,
            timestamp: Date().addingTimeInterval(-16 * 60) // 16 minutes ago
        )
        if let data = try? JSONEncoder().encode(envelope) {
            try? data.write(to: PlacesCache.cacheURL, options: .atomic)
        }

        let loaded = PlacesCache.load(currentLocation: testLocation)
        XCTAssertNil(loaded, "Expired cache should return nil")
    }

    // MARK: - Corrupt data

    func testCorruptDataReturnsNil() {
        try? "not json".data(using: .utf8)?.write(to: PlacesCache.cacheURL, options: .atomic)
        let loaded = PlacesCache.load(currentLocation: testLocation)
        XCTAssertNil(loaded)
    }

    // MARK: - Distance recalculation on load

    func testDistancesRecalculatedOnLoad() {
        let places = makePlaces(count: 1)
        PlacesCache.save(places: places, userLocation: testLocation)

        // Load from a slightly different location — distances should differ.
        let newLocation = CLLocation(latitude: 40.7310, longitude: -73.9892)
        let loaded = PlacesCache.load(currentLocation: newLocation)
        XCTAssertNotNil(loaded)
        // Distance should be different from original since we moved.
        if let loadedPlace = loaded?.first, let originalPlace = places.first {
            XCTAssertNotEqual(loadedPlace.distanceMeters, originalPlace.distanceMeters, accuracy: 0.1)
        }
    }

    // MARK: - Stale location returns nil

    func testStaleLocationReturnsNil() {
        let places = makePlaces()
        PlacesCache.save(places: places, userLocation: testLocation)

        // 1 km away — beyond the 500m staleness threshold.
        let farLocation = CLLocation(latitude: 40.7408, longitude: -73.9892)
        let loaded = PlacesCache.load(currentLocation: farLocation)
        XCTAssertNil(loaded, "Cache should be stale when user moved > 500m")
    }

    // MARK: - Clear

    func testClearRemovesCache() {
        let places = makePlaces()
        PlacesCache.save(places: places, userLocation: testLocation)
        PlacesCache.clear()

        let loaded = PlacesCache.load(currentLocation: testLocation)
        XCTAssertNil(loaded)
    }

    // MARK: - Sorting on load

    func testLoadedPlacesSortedByDistance() {
        // Save places in reverse distance order.
        let places = makePlaces(count: 3).reversed().map { $0 }
        PlacesCache.save(places: places, userLocation: testLocation)

        let loaded = PlacesCache.load(currentLocation: testLocation)
        XCTAssertNotNil(loaded)
        if let loaded = loaded, loaded.count > 1 {
            for i in 0..<(loaded.count - 1) {
                XCTAssertLessThanOrEqual(loaded[i].distanceMeters, loaded[i + 1].distanceMeters)
            }
        }
    }
}

// MARK: - Test helper to simulate expired cache

private struct ExpiredEnvelope: Codable {
    let places: [Place]
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}
