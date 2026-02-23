import SwiftUI

struct SettingsView: View {
    @AppStorage(AppStorageKey.mysteryMode) private var mysteryModeEnabled: Bool = false
    @AppStorage(AppStorageKey.distanceUnit) private var distanceUnit: DistanceUnit = .pizzaSlices
    @AppStorage(AppStorageKey.preferredMapsApp) private var preferredApp: String = "apple"
    @AppStorage(AppStorageKey.hasChosenMapsApp) private var hasChosenMapsApp: Bool = false

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
        }
    }
}
