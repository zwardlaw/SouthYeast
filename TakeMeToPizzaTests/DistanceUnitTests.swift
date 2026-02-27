@testable import TakeMeToPizza
import XCTest

final class DistanceUnitTests: XCTestCase {

    // MARK: - Raw value round-trips

    func testRawValueRoundTrip() {
        for unit in DistanceUnit.allCases {
            XCTAssertEqual(DistanceUnit(rawValue: unit.rawValue), unit)
        }
    }

    // MARK: - Pizza slices formatting

    func testPizzaSlicesZeroDistance() {
        XCTAssertEqual((0.0).distanceString(unit: .pizzaSlices), "0 slices away")
    }

    func testPizzaSlicesShortDistance() {
        // 100 meters / 0.2032 = ~492 slices
        let result = (100.0).distanceString(unit: .pizzaSlices)
        XCTAssertTrue(result.contains("492"))
        XCTAssertTrue(result.hasSuffix("slices away"))
    }

    func testPizzaSlicesLongDistance() {
        // 1000 meters / 0.2032 = ~4,921 slices
        let result = (1000.0).distanceString(unit: .pizzaSlices)
        XCTAssertTrue(result.contains("4,921") || result.contains("4921"))
        XCTAssertTrue(result.hasSuffix("slices away"))
    }

    // MARK: - Imperial formatting

    func testImperialFeetUnderMile() {
        // 100 meters = ~328 feet
        let result = (100.0).distanceString(unit: .imperial)
        XCTAssertTrue(result.contains("328"))
        XCTAssertTrue(result.hasSuffix("ft away"))
    }

    func testImperialMilesAtThreshold() {
        // 1609.34 meters = 5280 feet = 1.0 mile
        let result = (1609.344).distanceString(unit: .imperial)
        XCTAssertTrue(result.hasSuffix("mi away"))
        XCTAssertTrue(result.contains("1.0"))
    }

    func testImperialMilesAboveThreshold() {
        // 3218.69 meters = ~2.0 miles
        let result = (3218.69).distanceString(unit: .imperial)
        XCTAssertTrue(result.hasSuffix("mi away"))
        XCTAssertTrue(result.contains("2.0"))
    }

    func testImperialJustUnderMile() {
        // 1600 meters = ~5249 feet — should show feet
        let result = (1600.0).distanceString(unit: .imperial)
        XCTAssertTrue(result.hasSuffix("ft away"))
    }

    // MARK: - Metric formatting

    func testMetricMetersUnderKm() {
        let result = (500.0).distanceString(unit: .metric)
        XCTAssertEqual(result, "500 m away")
    }

    func testMetricKmAtThreshold() {
        let result = (1000.0).distanceString(unit: .metric)
        XCTAssertEqual(result, "1.0 km away")
    }

    func testMetricKmAboveThreshold() {
        let result = (2500.0).distanceString(unit: .metric)
        XCTAssertEqual(result, "2.5 km away")
    }

    func testMetricZeroDistance() {
        let result = (0.0).distanceString(unit: .metric)
        XCTAssertEqual(result, "0 m away")
    }

    // MARK: - Display names

    func testDisplayNames() {
        XCTAssertEqual(DistanceUnit.pizzaSlices.displayName, "Pizza Slices")
        XCTAssertEqual(DistanceUnit.imperial.displayName, "Imperial")
        XCTAssertEqual(DistanceUnit.metric.displayName, "Metric")
    }
}
