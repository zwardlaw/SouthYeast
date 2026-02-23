import Foundation
import CoreLocation
import MapKit

struct Place: Identifiable, Equatable, Codable {
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

    /// Memberwise init used by withUpdatedDistance, Codable, and tests.
    init(
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

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, address, phoneNumber, websiteURL, distanceMeters
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        let lat = try c.decode(Double.self, forKey: .latitude)
        let lon = try c.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        address = try c.decode(String.self, forKey: .address)
        phoneNumber = try c.decodeIfPresent(String.self, forKey: .phoneNumber)
        websiteURL = try c.decodeIfPresent(URL.self, forKey: .websiteURL)
        distanceMeters = try c.decode(Double.self, forKey: .distanceMeters)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(coordinate.latitude, forKey: .latitude)
        try c.encode(coordinate.longitude, forKey: .longitude)
        try c.encode(address, forKey: .address)
        try c.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try c.encodeIfPresent(websiteURL, forKey: .websiteURL)
        try c.encode(distanceMeters, forKey: .distanceMeters)
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

    /// Distance string formatted for the given unit preference.
    func distanceDisplayString(for unit: DistanceUnit) -> String {
        distanceMeters.distanceString(unit: unit)
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
