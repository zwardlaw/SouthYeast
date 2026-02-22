import SwiftUI

// MARK: - CarouselView

/// Horizontal snap-to-card carousel displayed as a brutalist overlay
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
    // Toggled to kick off the spin animation on MysteryToggleCard.
    @State private var mysterySpinTrigger = false

    @AppStorage(AppStorageKey.mysteryMode) private var mysteryModeEnabled: Bool = false

    // Fixed ID for the mystery toggle card -- never collides with place UUIDs.
    private let mysteryCardID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

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
    }

    // MARK: - Carousel

    @ViewBuilder
    private func placesCarousel(cardWidth: CGFloat, totalWidth: CGFloat) -> some View {
        let sideInset = (totalWidth - cardWidth) / 2

        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                // Mystery toggle card is the leftmost card — discovered by swiping right.
                // Square shape, same height as place cards but narrower.
                MysteryToggleCard(cardWidth: 100, spinTrigger: $mysterySpinTrigger)
                    .frame(width: 100)
                    .id(mysteryCardID)

                ForEach(placesService.places) { place in
                    CardView(
                        place: place,
                        isExpanded: expandedID == place.id,
                        mysteryModeEnabled: mysteryModeEnabled,
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
            // Shift left so the mystery card hides offscreen; only the
            // place cards are visible until the user pulls right.
            .padding(.leading, sideInset - 112)
            .padding(.trailing, sideInset)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollID)
        .task(id: placesService.places.first?.id) {
            // Scroll to first place card on initial load (past the mystery card).
            if scrollID == nil || scrollID == mysteryCardID,
               let firstPlace = placesService.places.first {
                scrollID = firstPlace.id
            }
        }
        .onChange(of: scrollID) { _, newID in
            guard isUserScrolling, let newID else { return }

            if newID == mysteryCardID {
                // Kick off the 360° spin (card toggles mystery mode at midpoint).
                mysterySpinTrigger.toggle()
                Task { @MainActor in
                    // Wait for spin to finish (600ms) + brief settle.
                    try? await Task.sleep(for: .milliseconds(800))
                    // Snap back to first place card.
                    isUserScrolling = false
                    scrollID = placesService.places.first?.id
                    try? await Task.sleep(for: .milliseconds(500))
                    isUserScrolling = true
                }
                return
            }

            if let place = placesService.places.first(where: { $0.id == newID }) {
                appState.selectedPlace = place
                expandedID = nil
                appState.updateCompassAngle()
            }
        }
    }
}

// MARK: - CardView

struct CardView: View {
    let place: Place
    let isExpanded: Bool
    let mysteryModeEnabled: Bool
    let onTap: () -> Void

    @AppStorage(AppStorageKey.preferredMapsApp) private var preferredApp: String = "apple"
    @AppStorage(AppStorageKey.hasChosenMapsApp) private var hasChosenMapsApp: Bool = false
    @State private var showMapsChoice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsed content -- always visible.
            Text(place.name)
                .font(.pizzaDisplay(size: 18))
                .lineLimit(1)
                .mysteryRedacted(isActive: mysteryModeEnabled)

            Text(place.distanceDisplayString)
                .font(.pizzaBody(size: 14))
                .foregroundStyle(.secondary)
            // Distance is never redacted in mystery mode.

            // Expanded content -- conditional.
            if isExpanded {
                Divider()

                if !place.address.isEmpty {
                    Label(place.address, systemImage: "mappin.circle")
                        .font(.pizzaBody(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .mysteryRedacted(isActive: mysteryModeEnabled)
                }

                if let phone = place.phoneNumber {
                    Label(phone, systemImage: "phone")
                        .font(.pizzaBody(size: 12))
                        .foregroundStyle(.secondary)
                        .mysteryRedacted(isActive: mysteryModeEnabled)
                }

                if let website = place.websiteURL {
                    Link(destination: website) {
                        Label("Website", systemImage: "globe")
                            .font(.pizzaBody(size: 12))
                    }
                    .tint(.pizzaOrange)
                    .mysteryRedacted(isActive: mysteryModeEnabled)
                }

                // Directions button is never redacted -- navigation always works.
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
                            .font(.pizzaDisplay(size: 16))
                    }
                    .frame(maxWidth: .infinity)
                }
                .brutalistButton()
                .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalistCard()
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
                .font(.system(size: 36))
                .foregroundStyle(Color.pizzaOrange)
            Text(title)
                .font(.pizzaDisplay(size: 20))
            Text(subtitle)
                .font(.pizzaBody(size: 13))
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.pizzaCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.3), lineWidth: 1.5)
                        )
                        .frame(width: cardWidth, height: 80)
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

// MARK: - Previews

#if DEBUG
#Preview("Card - Collapsed") {
    CardView(
        place: Place.samplePlaces[0],
        isExpanded: false,
        mysteryModeEnabled: false,
        onTap: {}
    )
    .padding()
    .background(Color.pizzaBackground)
}

#Preview("Card - Expanded") {
    CardView(
        place: Place.samplePlaces[0],
        isExpanded: true,
        mysteryModeEnabled: false,
        onTap: {}
    )
    .padding()
    .background(Color.pizzaBackground)
}

#Preview("Card - Mystery Mode") {
    CardView(
        place: Place.samplePlaces[0],
        isExpanded: true,
        mysteryModeEnabled: true,
        onTap: {}
    )
    .padding()
    .background(Color.pizzaBackground)
}

#Preview("Full Carousel") {
    let location = LocationService()
    let places = PlacesService()
    places.places = Place.samplePlaces
    let state = AppState(locationService: location, placesService: places)
    state.selectedPlace = Place.samplePlaces.first
    let network = NetworkMonitor()
    return CarouselView()
        .frame(height: 160)
        .background(Color.pizzaBackground)
        .environment(location)
        .environment(places)
        .environment(state)
        .environment(network)
}
#endif
