import Foundation

/// Centralized @AppStorage key string constants.
/// Use these instead of inline string literals to prevent typos
/// and simplify future key renaming.
enum AppStorageKey {
    /// Whether mystery mode is active (destination hidden until arrival).
    static let mysteryMode = "mysteryModeEnabled"

    /// Whether the user has completed the onboarding flow.
    static let hasCompletedOnboarding = "hasCompletedOnboarding"

    /// User's preferred maps application for turn-by-turn navigation.
    static let preferredMapsApp = "preferredMapsApp"

    /// Whether the user has explicitly chosen a maps app.
    static let hasChosenMapsApp = "hasChosenMapsApp"
}
