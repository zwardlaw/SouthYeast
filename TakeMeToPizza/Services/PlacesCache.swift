import Foundation
import CoreLocation

/// Disk-backed cache for nearby pizza places with a 15-minute TTL.
/// Stores JSON in the Caches directory so the system can reclaim space.
enum PlacesCache: Sendable {

    private static let ttl: TimeInterval = 15 * 60 // 15 minutes
    private static let maxStaleDistance: CLLocationDistance = 500 // meters

    // MARK: - Public API

    /// Persists places and the user location they were fetched from.
    static func save(places: [Place], userLocation: CLLocation) {
        let envelope = CacheEnvelope(
            places: places,
            latitude: userLocation.coordinate.latitude,
            longitude: userLocation.coordinate.longitude,
            timestamp: Date()
        )
        do {
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            // Cache write failure is non-fatal — next launch will re-fetch.
        }
    }

    /// Loads cached places if the cache is fresh (< TTL) and the user hasn't
    /// moved more than 500 m from the cached location. Recalculates distances
    /// from the current location and re-sorts.
    static func load(currentLocation: CLLocation) -> [Place]? {
        guard let data = try? Data(contentsOf: cacheURL),
              let envelope = try? JSONDecoder().decode(CacheEnvelope.self, from: data) else {
            return nil
        }

        // TTL check.
        guard Date().timeIntervalSince(envelope.timestamp) < ttl else {
            return nil
        }

        // Staleness check — user moved too far from cached fetch origin.
        let cachedLocation = CLLocation(latitude: envelope.latitude, longitude: envelope.longitude)
        guard currentLocation.distance(from: cachedLocation) < maxStaleDistance else {
            return nil
        }

        // Recalculate distances from current position and re-sort.
        return envelope.places
            .map { $0.withUpdatedDistance(userLocation: currentLocation) }
            .sorted { $0.distanceMeters < $1.distanceMeters }
    }

    /// Removes the cache file.
    static func clear() {
        try? FileManager.default.removeItem(at: cacheURL)
    }

    // MARK: - Internal (visible for tests)

    static var cacheURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("places_cache.json")
    }
}

// MARK: - Cache Envelope

private struct CacheEnvelope: Codable {
    let places: [Place]
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}
