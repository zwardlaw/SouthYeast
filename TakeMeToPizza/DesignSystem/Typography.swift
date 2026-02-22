import SwiftUI

extension Font {
    // MARK: - Pizza Typography

    /// Impact -- bold display face for headings, place names, distances.
    /// Scales with Dynamic Type relative to the `title` text style.
    static func pizzaDisplay(size: CGFloat) -> Font {
        Font.custom("Impact", size: size, relativeTo: .title)
    }

    /// Space Grotesk -- clean geometric sans for body copy, labels, captions.
    /// Scales with Dynamic Type relative to the `body` text style.
    static func pizzaBody(size: CGFloat) -> Font {
        Font.custom("SpaceGrotesk-Regular", size: size, relativeTo: .body)
    }

    // MARK: - Convenience sizes

    /// Caption text -- 12pt Space Grotesk.
    static let pizzaCaption = pizzaBody(size: 12)

    /// Headline text -- 16pt Space Grotesk.
    static let pizzaHeadline = pizzaBody(size: 16)
}
