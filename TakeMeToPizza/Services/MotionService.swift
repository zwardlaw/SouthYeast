import CoreMotion
import Observation

/// Wraps CMMotionManager to expose device roll and pitch for tilt parallax.
/// All mutations happen on the main queue -- safe with @Observable + @MainActor.
@Observable
@MainActor
final class MotionService {
    /// Device roll (left/right tilt), in radians. Updated at ~20 Hz.
    var roll: Double = 0.0

    /// Device pitch (forward/back tilt), in radians. Updated at ~20 Hz.
    var pitch: Double = 0.0

    private let manager = CMMotionManager()

    /// Begin device motion updates at 20 Hz. No-op if hardware unavailable (Simulator).
    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 20.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let attitude = data?.attitude else { return }
            self?.roll = attitude.roll
            self?.pitch = attitude.pitch
        }
    }

    /// Stop device motion updates. Call when the view disappears or app backgrounds.
    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
