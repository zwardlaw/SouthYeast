import CoreLocation
import Foundation

extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}

/// Returns bearing in degrees (0-360) from geographic north.
/// Uses the haversine/forward-azimuth formula.
func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let lat1 = from.latitude.degreesToRadians
    let lat2 = to.latitude.degreesToRadians
    let dLon = (to.longitude - from.longitude).degreesToRadians
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let b = atan2(y, x).radiansToDegrees
    return (b + 360).truncatingRemainder(dividingBy: 360)
}

/// Normalizes an angle delta to [-180, 180] for shortest-arc animation.
/// Prevents full-circle spins when the needle crosses 0/360.
func normalizeAngleDelta(_ delta: Double) -> Double {
    var d = delta.truncatingRemainder(dividingBy: 360)
    if d > 180  { d -= 360 }
    if d < -180 { d += 360 }
    return d
}
