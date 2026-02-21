import Foundation
import CoreLocation

struct Place: Identifiable, Equatable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D

    // Equatable conformance for CLLocationCoordinate2D
    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.id == rhs.id
    }
}
