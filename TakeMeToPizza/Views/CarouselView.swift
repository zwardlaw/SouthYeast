import SwiftUI

// MARK: - CarouselView

/// Horizontal snap-to-card carousel displayed as a translucent overlay
/// at the bottom of CompassView. Shows real nearby pizza places from
/// PlacesService, handles expand/collapse of individual cards, and
/// renders empty, error, and loading states.
struct CarouselView: View {
    @Environment(AppState.self) private var appState
    @Environment(PlacesService.self) private var placesService
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(LocationService.self) private var locationService

    @State private var scrollID: UUID?
    @State private var expandedID: UUID?
    // Guards against programmatic scroll triggering onChange re-entrantly.
    @State private var isUserScrolling = true

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = proxy.size.width - 80   // 40pt peek on each side

            Group {
                if !networkMonitor.isConnected {
                    StateCard(
                        symbol: "wifi.slash",
                        title: "No internet connection",
                        subtitle: "Connect to find pizza nearby"
                    )
                } else if case .noResults = placesService.error {
                    StateCard(
                        symbol: "takeoutbag.and.cup.and.straw",
                        title: "No pizza nearby",
                        subtitle: "Try moving to a different area"
                    )
                } else if placesService.error != nil {
                    StateCard(
                        symbol: "exclamationmark.triangle",
                        title: "Something went wrong",
                        subtitle: "Pull down to try again"
                    )
                } else if placesService.isLoading && placesService.places.isEmpty {
                    LoadingSkeleton(cardWidth: cardWidth)
                } else {
                    placesCarousel(cardWidth: cardWidth, totalWidth: proxy.size.width)
                }
            }
        }
        .frame(height: expandedID != nil ? 280 : 140)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: expandedID)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Carousel

    @ViewBuilder
    private func placesCarousel(cardWidth: CGFloat, totalWidth: CGFloat) -> some View {
        let sideInset = (totalWidth - cardWidth) / 2

        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(placesService.places) { place in
                    CardView(
                        place: place,
                        isExpanded: expandedID == place.id,
                        onTap: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if expandedID == place.id {
                                    expandedID = nil
                                } else {
                                    expandedID = place.id
                                }
                            }
                        }
                    )
                    .frame(width: cardWidth)
                    .id(place.id)
                    .onAppear {
                        // Load more when scrolling near the last 3 places.
                        let places = placesService.places
                        guard places.count >= 3 else { return }
                        let threshold = places[places.count - 3].id
                        if place.id == threshold {
                            if let location = locationService.location {
                                Task {
                                    await placesService.loadMore(userLocation: location)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, sideInset)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollID)
        .onChange(of: scrollID) { _, newID in
            guard isUserScrolling, let newID else { return }
            if let place = placesService.places.first(where: { $0.id == newID }) {
                appState.selectedPlace = place
                expandedID = nil
                appState.updateCompassAngle()
            }
        }
    }
}

// MARK: - CardView

private struct CardView: View {
    let place: Place
    let isExpanded: Bool
    let onTap: () -> Void

    @AppStorage("preferredMapsApp") private var preferredApp: String = "apple"
    @AppStorage("hasChosenMapsApp") private var hasChosenMapsApp: Bool = false
    @State private var showMapsChoice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsed content -- always visible.
            Text(place.name)
                .font(.headline)
                .lineLimit(1)

            Text(place.distanceDisplayString)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Expanded content -- conditional.
            if isExpanded {
                Divider()

                if !place.address.isEmpty {
                    Label(place.address, systemImage: "mappin.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let phone = place.phoneNumber {
                    Label(phone, systemImage: "phone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let website = place.websiteURL {
                    Link(destination: website) {
                        Label("Website", systemImage: "globe")
                            .font(.caption)
                    }
                    .tint(.orange)
                }

                Button {
                    if !hasChosenMapsApp {
                        showMapsChoice = true
                    } else {
                        openDirections(to: place, preferredApp: preferredApp)
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                        Text("Get Directions")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            onTap()
        }
        .confirmationDialog("Choose Maps App", isPresented: $showMapsChoice) {
            Button("Google Maps") {
                preferredApp = "google"
                hasChosenMapsApp = true
                openDirections(to: place, preferredApp: "google")
            }
            Button("Apple Maps") {
                preferredApp = "apple"
                hasChosenMapsApp = true
                openDirections(to: place, preferredApp: "apple")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose your preferred maps app for walking directions")
        }
    }
}

// MARK: - State Cards

private struct StateCard: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

private struct LoadingSkeleton: View {
    let cardWidth: CGFloat

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: cardWidth, height: 80)
                        .redacted(reason: .placeholder)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Directions Handoff

@MainActor
private func openDirections(to place: Place, preferredApp: String) {
    let lat = place.coordinate.latitude
    let lng = place.coordinate.longitude

    if preferredApp == "google",
       let googleURL = URL(string: "comgooglemaps://"),
       UIApplication.shared.canOpenURL(googleURL),
       let deepLink = URL(string: "comgooglemaps://?saddr=&daddr=\(lat),\(lng)&directionsmode=walking") {
        UIApplication.shared.open(deepLink)
        return
    }

    // Fallback: Apple Maps with walking directions.
    if let appleURL = URL(string: "http://maps.apple.com/?daddr=\(lat),\(lng)&dirflg=w") {
        UIApplication.shared.open(appleURL)
    }
}
