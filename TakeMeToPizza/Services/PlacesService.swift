import Observation
import CoreLocation
import MapKit

// MARK: - PlacesError

enum PlacesError: Error {
    case searchFailed(Error)
    case noResults
    case noLocation
}

// MARK: - PlacesService

/// Live MKLocalSearch integration that fetches nearby pizza places,
/// sorts by distance, supports load-more radius expansion, and can
/// recalculate distances in-place when the user moves.
@Observable
@MainActor
final class PlacesService {

    // MARK: Published State

    var places: [Place] = []
    var isLoading = false
    var error: PlacesError?

    // MARK: Private State

    private var searchRegionRadiusKm: Double = 1.0
    private let radiusStepKm: Double = 1.0
    private let maxRadiusKm: Double = 10.0

    // MARK: - Public API

    /// Fetches pizza places near the user's current location using MKLocalSearch.
    /// Resets search radius on each fresh fetch.
    /// Sets `isLoading` during the operation; populates `places` or `error` on completion.
    func fetchNearby(userLocation: CLLocation) async {
        isLoading = true
        error = nil
        searchRegionRadiusKm = 1.0

        defer { isLoading = false }

        do {
            let items = try await search(center: userLocation.coordinate,
                                        radiusMeters: searchRegionRadiusKm * 1000)
            let sorted = items
                .map { Place(from: $0, userLocation: userLocation) }
                .sorted { $0.distanceMeters < $1.distanceMeters }

            if sorted.isEmpty {
                error = .noResults
            } else {
                places = sorted
            }
        } catch {
            self.error = .searchFailed(error)
        }
    }

    /// Expands the search radius and appends newly discovered places,
    /// deduplicating against already-fetched results by coordinate proximity (< 10 m).
    /// Does nothing if the maximum radius has already been reached.
    func loadMore(userLocation: CLLocation) async {
        guard searchRegionRadiusKm < maxRadiusKm else { return }
        searchRegionRadiusKm += radiusStepKm

        isLoading = true
        defer { isLoading = false }

        do {
            let items = try await search(center: userLocation.coordinate,
                                        radiusMeters: searchRegionRadiusKm * 1000)
            let newPlaces = items
                .map { Place(from: $0, userLocation: userLocation) }
                .filter { candidate in
                    !places.contains { existing in
                        let existingLocation = CLLocation(
                            latitude: existing.coordinate.latitude,
                            longitude: existing.coordinate.longitude
                        )
                        let candidateLocation = CLLocation(
                            latitude: candidate.coordinate.latitude,
                            longitude: candidate.coordinate.longitude
                        )
                        return existingLocation.distance(from: candidateLocation) < 10.0
                    }
                }

            var merged = places + newPlaces
            merged.sort { $0.distanceMeters < $1.distanceMeters }
            places = merged
        } catch {
            self.error = .searchFailed(error)
        }
    }

    /// Recalculates `distanceMeters` on every cached place for a new user location.
    /// Does NOT re-query MKLocalSearch. Re-sorts by new distance after updating.
    func updateDistances(userLocation: CLLocation) {
        places = places
            .map { $0.withUpdatedDistance(userLocation: userLocation) }
            .sorted { $0.distanceMeters < $1.distanceMeters }
    }

    // MARK: - Private Helpers

    /// Executes a MKLocalSearch for pizza restaurants within the given radius.
    private func search(center: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "pizza"
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant])
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )

        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems
    }
}
