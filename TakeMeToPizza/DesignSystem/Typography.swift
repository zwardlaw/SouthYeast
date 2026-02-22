import SwiftUI

extension Font {
    // MARK: - Pizza Typography

    /// Bebas Neue -- bold display face for headings, place names, distances.
    static func pizzaDisplay(size: CGFloat) -> Font {
        Font.custom("BebasNeue-Regular", size: size)
    }

    /// Space Grotesk -- clean geometric sans for body copy, labels, captions.
    /// PostScript name for the variable font at regular weight.
    static func pizzaBody(size: CGFloat) -> Font {
        Font.custom("SpaceGrotesk-Regular", size: size)
    }

    // MARK: - Convenience sizes

    /// Caption text -- 12pt Space Grotesk.
    static let pizzaCaption = pizzaBody(size: 12)

    /// Headline text -- 16pt Space Grotesk.
    static let pizzaHeadline = pizzaBody(size: 16)
}
