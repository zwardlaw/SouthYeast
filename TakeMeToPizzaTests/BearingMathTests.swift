import XCTest
import CoreLocation
@testable import TakeMeToPizza

final class BearingMathTests: XCTestCase {

    // MARK: - Cardinal direction tests

    /// North: moving from (0,0) to (1,0) — increasing latitude, same longitude.
    func testBearingNorth() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let to   = CLLocationCoordinate2D(latitude: 1, longitude: 0)
        XCTAssertEqual(bearing(from: from, to: to), 0.0, accuracy: 0.1)
    }

    /// East: moving from (0,0) to (0,1) — same latitude, increasing longitude.
    func testBearingEast() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let to   = CLLocationCoordinate2D(latitude: 0, longitude: 1)
        XCTAssertEqual(bearing(from: from, to: to), 90.0, accuracy: 0.1)
    }

    /// South: moving from (1,0) to (0,0) — decreasing latitude, same longitude.
    func testBearingSouth() {
        let from = CLLocationCoordinate2D(latitude: 1, longitude: 0)
        let to   = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        XCTAssertEqual(bearing(from: from, to: to), 180.0, accuracy: 0.1)
    }

    /// West: moving from (0,1) to (0,0) — same latitude, decreasing longitude.
    func testBearingWest() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 1)
        let to   = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        XCTAssertEqual(bearing(from: from, to: to), 270.0, accuracy: 0.1)
    }

    // MARK: - Shortest-arc normalization

    /// Crossing north boundary: 10 -> 350 should produce +20 (clockwise 20 degrees),
    /// and 350 -> 10 should produce -20 (counter-clockwise 20 degrees).
    func testNormalizeDeltaShortestArc() {
        // Heading moves from 350 to 10 (crosses north going clockwise).
        // Raw delta = 10 - 350 = -340. Shortest arc = +20.
        XCTAssertEqual(normalizeAngleDelta(10 - 350), 20.0, accuracy: 0.001)

        // Heading moves from 10 to 350 (crosses north going counter-clockwise).
        // Raw delta = 350 - 10 = 340. Shortest arc = -20.
        XCTAssertEqual(normalizeAngleDelta(350 - 10), -20.0, accuracy: 0.001)
    }
}
