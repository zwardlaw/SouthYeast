import SwiftUI
import StoreKit

struct SettingsView: View {
    @AppStorage(AppStorageKey.mysteryMode) private var mysteryModeEnabled: Bool = false
    @AppStorage(AppStorageKey.distanceUnit) private var distanceUnit: DistanceUnit = .pizzaSlices
    @AppStorage(AppStorageKey.preferredMapsApp) private var preferredApp: String = "apple"
    @AppStorage(AppStorageKey.hasChosenMapsApp) private var hasChosenMapsApp: Bool = false

    @State private var tipService = TipJarService()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Mystery Mode") {
                    Toggle("Mystery Mode", isOn: $mysteryModeEnabled)
                    Text("Hides restaurant names so the pizza slice picks for you.")
                        .font(.pizzaBody(size: 13))
                        .foregroundStyle(.secondary)
                }

                Section("Distance") {
                    Picker("Unit", selection: $distanceUnit) {
                        ForEach(DistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }

                Section("Directions") {
                    Picker("Maps App", selection: $preferredApp) {
                        Text("Apple Maps").tag("apple")
                        Text("Google Maps").tag("google")
                    }
                    .onChange(of: preferredApp) {
                        hasChosenMapsApp = true
                    }
                }

                tipJarSection

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.pizzaDisplay(size: 16))
                }
            }
            .onAppear { tipService.start() }
        }
    }

    // MARK: - Tip Jar

    @ViewBuilder
    private var tipJarSection: some View {
        Section {
            if tipService.products.isEmpty {
                if let error = tipService.loadError {
                    Text(error)
                        .font(.pizzaBody(size: 13))
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(tipService.products, id: \.id) { product in
                        tipButton(for: product)
                    }

                    switch tipService.purchaseState {
                    case .thankyou(let slices):
                        Text("You just mass-donated \(slices) pizza slices. Legend.")
                            .font(.pizzaBody(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    case .failed(let message):
                        Text(message)
                            .font(.pizzaBody(size: 13))
                            .foregroundStyle(.red)
                    default:
                        EmptyView()
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }
        } header: {
            Text("Buy Me a Slice")
        } footer: {
            Text("This app is 100% free. Tips go straight to the pizza fund.")
                .font(.pizzaBody(size: 12))
        }
    }

    private func tipButton(for product: Product) -> some View {
        Button {
            Task { await tipService.purchase(product) }
        } label: {
            HStack {
                Text(emoji(for: product.id))
                    .font(.system(size: 20))
                Text(tierName(for: product.id))
                    .font(.pizzaDisplay(size: 16))
                Spacer()
                Text(product.displayPrice)
                    .font(.pizzaBody(size: 14))
            }
            .foregroundStyle(.black)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color.pizzaOrange)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .offset(x: 3, y: 3)
            )
        }
        .buttonStyle(BrutalistPressStyle())
        .disabled(tipService.purchaseState == .purchasing)
    }

    private func emoji(for id: String) -> String {
        switch id {
        case "tip.slice": return "\u{1F355}"
        case "tip.pie": return "\u{1F355}\u{1F355}"
        case "tip.party": return "\u{1F389}"
        default: return "\u{1F355}"
        }
    }

    private func tierName(for id: String) -> String {
        switch id {
        case "tip.slice": return "A Slice"
        case "tip.pie": return "A Whole Pie"
        case "tip.party": return "The Pizza Party"
        default: return "Tip"
        }
    }
}
