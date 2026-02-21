import Observation
import CoreLocation

@Observable
@MainActor
final class PlacesService {
    // Hardcoded test places for Phase 1 compass verification.
    // Three well-known NYC pizza spots with clearly different bearings from each other.
    // Real MKLocalSearch integration (INFR-06) replaces this in Phase 2.
    var places: [Place] = [
        // Joe's Pizza — Greenwich Village (northwest bearing from center)
        Place(id: UUID(), name: "Joe's Pizza", coordinate: CLLocationCoordinate2D(latitude: 40.7306, longitude: -73.9866)),
        // Di Fara Pizza — Midwood, Brooklyn (southeast bearing from center)
        Place(id: UUID(), name: "Di Fara Pizza", coordinate: CLLocationCoordinate2D(latitude: 40.6250, longitude: -73.9613)),
        // Lucali — Carroll Gardens, Brooklyn (south-southwest bearing from center)
        Place(id: UUID(), name: "Lucali", coordinate: CLLocationCoordinate2D(latitude: 40.6834, longitude: -73.9967))
    ]
}
