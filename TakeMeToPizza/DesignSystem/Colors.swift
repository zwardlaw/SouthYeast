import SwiftUI

extension Color {
    // MARK: - Pizza Palette Tokens
    // Each color references an Asset Catalog color set that provides
    // adaptive Any/Dark appearances automatically.

    /// Deep red -- primary action, needle, crust accent.
    static let pizzaRed = Color("PizzaRed")

    /// Warm orange -- cheese base fill, primary accent.
    static let pizzaOrange = Color("PizzaOrange")

    /// Golden yellow -- alignment glow, highlights.
    static let pizzaGold = Color("PizzaGold")

    /// Card surface background. White in light mode, dark brown in dark mode.
    static let pizzaCard = Color("PizzaCard")

    /// Screen background. Off-white cream in light, near-black in dark.
    static let pizzaBackground = Color("PizzaBackground")
}
