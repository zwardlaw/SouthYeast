import Foundation
import CoreLocation
import MapKit

struct Place: Identifiable, Equatable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let address: String
    let phoneNumber: String?
    let websiteURL: URL?
    var distanceMeters: Double

    // MARK: - Initializers

    /// Primary init from MKMapItem. Computes distance from user's current location.
    init(from mapItem: MKMapItem, userLocation: CLLocation) {
        self.id = UUID()
        self.name = mapItem.name ?? "Unknown"
        self.coordinate = mapItem.placemark.coordinate
        self.phoneNumber = mapItem.phoneNumber
        self.websiteURL = mapItem.url

        // Build address from placemark components.
        let placemark = mapItem.placemark
        var parts: [String] = []
        if let sub = placemark.subThoroughfare { parts.append(sub) }
        if let thoroughfare = placemark.thoroughfare {
            if parts.isEmpty {
                parts.append(thoroughfare)
            } else {
                parts[parts.count - 1] += " \(thoroughfare)"
            }
        }
        if let locality = placemark.locality { parts.append(locality) }
        self.address = parts.joined(separator: ", ")

        let itemLocation = CLLocation(
            latitude: mapItem.placemark.coordinate.latitude,
            longitude: mapItem.placemark.coordinate.longitude
        )
        self.distanceMeters = userLocation.distance(from: itemLocation)
    }

    /// Internal memberwise init used by withUpdatedDistance.
    private init(
        id: UUID,
        name: String,
        coordinate: CLLocationCoordinate2D,
        address: String,
        phoneNumber: String?,
        websiteURL: URL?,
        distanceMeters: Double
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.address = address
        self.phoneNumber = phoneNumber
        self.websiteURL = websiteURL
        self.distanceMeters = distanceMeters
    }

    // MARK: - Computed Properties

    /// Distance expressed as pizza slices (1 slice = 8 inches = 0.2032 meters).
    var distanceInPizzaSlices: Int {
        Int((distanceMeters / 0.2032).rounded())
    }

    /// Human-readable distance string using pizza slices as unit.
    var distanceDisplayString: String {
        "\(distanceInPizzaSlices.formatted()) slices away"
    }

    // MARK: - Distance Update

    /// Returns a copy of this Place with distanceMeters recalculated from a new user location.
    /// Does NOT re-query MKLocalSearch — use PlacesService.updateDistances for bulk updates.
    func withUpdatedDistance(userLocation: CLLocation) -> Place {
        let itemLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        return Place(
            id: id,
            name: name,
            coordinate: coordinate,
            address: address,
            phoneNumber: phoneNumber,
            websiteURL: websiteURL,
            distanceMeters: userLocation.distance(from: itemLocation)
        )
    }

    // MARK: - Equatable

    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Preview Sample Data

    #if DEBUG
    static let samplePlaces: [Place] = [
        Place(
            id: UUID(),
            name: "Joe's Pizza",
            coordinate: .init(latitude: 40.7308, longitude: -73.9892),
            address: "7 Carmine St, New York",
            phoneNumber: "(212) 366-1182",
            websiteURL: URL(string: "https://joespizzanyc.com"),
            distanceMeters: 320
        ),
        Place(
            id: UUID(),
            name: "Di Fara Pizza",
            coordinate: .init(latitude: 40.6250, longitude: -73.9615),
            address: "1424 Avenue J, Brooklyn",
            phoneNumber: "(718) 258-1367",
            websiteURL: nil,
            distanceMeters: 870
        ),
        Place(
            id: UUID(),
            name: "Lucali",
            coordinate: .init(latitude: 40.6862, longitude: -73.9968),
            address: "575 Henry St, Brooklyn",
            phoneNumber: nil,
            websiteURL: nil,
            distanceMeters: 1540
        ),
    ]
    #endif
}
