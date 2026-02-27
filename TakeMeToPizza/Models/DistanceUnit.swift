import Foundation

/// User-selectable distance display unit.
/// RawRepresentable as String for direct @AppStorage compatibility.
enum DistanceUnit: String, CaseIterable, Sendable {
    case pizzaSlices
    case imperial
    case metric

    var displayName: String {
        switch self {
        case .pizzaSlices: return "Pizza Slices"
        case .imperial: return "Imperial"
        case .metric: return "Metric"
        }
    }
}

// MARK: - Distance Formatting

extension Double {
    /// Formats a distance in meters for the given unit.
    func distanceString(unit: DistanceUnit) -> String {
        switch unit {
        case .pizzaSlices:
            let slices = Int((self / 0.2032).rounded())
            return "\(slices.formatted()) slices away"
        case .imperial:
            let feet = self * 3.28084
            if feet < 5280 {
                return "\(Int(feet.rounded())) ft away"
            } else {
                let miles = feet / 5280
                return String(format: "%.1f mi away", miles)
            }
        case .metric:
            if self < 1000 {
                return "\(Int(self.rounded())) m away"
            } else {
                let km = self / 1000
                return String(format: "%.1f km away", km)
            }
        }
    }
}
