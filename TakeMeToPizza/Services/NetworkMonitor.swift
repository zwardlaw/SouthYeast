import Network
import Observation

/// NWPathMonitor wrapper that publishes network reachability to SwiftUI via @Observable.
/// Follows the same @Observable @MainActor pattern used by LocationService and PlacesService.
@Observable
@MainActor
final class NetworkMonitor {

    // MARK: Published State

    /// True when a satisfactory network path is available.
    var isConnected = true

    // MARK: Private

    private let monitor = NWPathMonitor()

    // MARK: Init / Deinit

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor", qos: .userInitiated))
    }

    deinit {
        monitor.cancel()
    }
}
