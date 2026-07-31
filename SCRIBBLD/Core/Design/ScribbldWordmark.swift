import SwiftUI

/// Single source of truth for rendering the "SCRIBBLD" wordmark anywhere
/// in the app.
///
/// Caveat's `D` glyph has visible ink that extends past the font's
/// advance-width. SwiftUI `Text` lays itself out using advance-width and
/// clips its rendering buffer at that edge, which is why every prior
/// trailing-padding fix (`size * 0.18`, `0.22`, etc.) still produced a
/// truncated D in production. The padding made the *parent* wider but
/// the *Text's own buffer* still cut off the tail.
///
/// `InkBoundsLabel` (a `UILabel`-backed `UIViewRepresentable`) sizes the
/// view to the glyph's actual ink-bounding rect via
/// `NSAttributedString.boundingRect` + `.usesDeviceMetrics`. Every
/// visible pixel of every glyph lives inside the reported size — no
/// clipping at any font size.
struct ScribbldWordmark: View {
    var size: CGFloat = 22
    var color: Color = .inkBlue

    var body: some View {
        InkBoundsLabel.caveat("SCRIBBLD", size: size, color: color)
            .fixedSize()
    }
}

#Preview {
    VStack(spacing: 14) {
        ScribbldWordmark(size: 16)
        ScribbldWordmark(size: 20)
        ScribbldWordmark(size: 28)
        ScribbldWordmark(size: 36)
        ScribbldWordmark(size: 56)
    }
    .padding()
    .background(Color.cream)
}
