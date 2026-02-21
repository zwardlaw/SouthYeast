import SwiftUI

struct CompassView: View {
    @Environment(AppState.self) private var appState
    @Environment(PlacesService.self) private var placesService

    var body: some View {
        VStack(spacing: 32) {
            if appState.isCalibrating {
                // Calibration state -- heading data unreliable
                VStack(spacing: 16) {
                    Image(systemName: "location.slash.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("Calibrating...")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Move your phone in a figure-eight pattern")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Phase 1 placeholder needle -- arrow pointing up, rotated by compass angle.
                // Phase 3 replaces this with the custom pizza slice Shape.
                Image(systemName: "location.north.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(appState.compassAngle))
                    .animation(
                        .interpolatingSpring(stiffness: 170, damping: 26),
                        value: appState.compassAngle
                    )
            }

            // Target name
            if let place = appState.selectedPlace {
                Text(place.name)
                    .font(.headline)
            }

            // Minimal place picker -- Phase 1 only.
            // Replaced by carousel in Phase 2.
            PlacePickerRow()
        }
    }
}

/// Minimal row of capsule buttons to switch between stub places.
/// Validates COMP-05 (place re-targeting) in Phase 1.
/// Replaced entirely by CarouselView in Phase 2.
private struct PlacePickerRow: View {
    @Environment(AppState.self) private var appState
    @Environment(PlacesService.self) private var placesService

    var body: some View {
        VStack(spacing: 8) {
            Text("Target")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(placesService.places) { place in
                    Button {
                        appState.selectedPlace = place
                    } label: {
                        Text(place.name)
                            .font(.caption)
                            .fontWeight(appState.selectedPlace?.id == place.id ? .bold : .regular)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                appState.selectedPlace?.id == place.id
                                    ? Color.orange.opacity(0.2)
                                    : Color.gray.opacity(0.1)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
    }
}
