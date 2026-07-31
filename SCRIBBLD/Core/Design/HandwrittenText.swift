import SwiftUI

/// Caveat-Regular has several glyphs (`D`, `K`, `R`, exclamation tails,
/// most lowercase italics) whose visible ink extends beyond the font's
/// reported advance width — i.e. negative right-side bearing. SwiftUI
/// lays out `Text` against advance width, so in any tight container the
/// last glyph's tail gets clipped on the right edge.
///
/// `HandwrittenText` bakes in the safety modifiers (proportional
/// trailing padding + `fixedSize` on the vertical axis) so callers can't
/// forget. Use it anywhere body/header text uses Caveat AND lives inside
/// a constrained frame (cards, capsules, segmented pickers, etc.).
///
/// For single-letter centered displays (Stop! letter reveal, alphabet
/// tiles) prefer `HandwrittenLetter` — it pads BOTH sides so a centered
/// glyph doesn't drift.
struct HandwrittenText: View {
    let text: String
    var size: CGFloat
    var weight: Font.Weight = .bold
    var color: Color = .inkBlue
    var alignment: TextAlignment = .leading
    var lineLimit: Int? = nil

    var body: some View {
        Text(text)
            .font(.caveat(size, weight: weight))
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .lineLimit(lineLimit)
            // Trailing ink room. Measured from Caveat-Regular.ttf directly
            // (glyf bounding box vs hmtx advance): the worst overshoots are
            // "(" at 0.211 of the font size, "I" 0.204, "F" 0.194, "f" 0.189,
            // "T" 0.187, "!" 0.185. Note D — which this system was originally
            // built around — is only 0.072, one of the mildest. 0.22 clears
            // every glyph in the face; the previous 0.20 did not.
            .padding(.trailing, max(4, size * 0.22))
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.85)
            // Lift text above any decorative background layers in
            // parent ZStacks. Cheap insurance against future
            // overlay/hatch additions covering the trailing glyph.
            .zIndex(1)
    }
}

/// Centered single-letter handwritten display — Stop! letter randomizer
/// and any future alphabet UI.
///
/// Previously implemented as `Text` + trailing padding + `fixedSize` +
/// `rotationEffect`. That left the K, R, D etc. clipped on the right
/// because SwiftUI's `Text` uses font *advance-width* bounds, and the
/// visible ink for those glyphs extends past advance-width.
///
/// Now wraps `InkBoundsLabel`, which sizes via
/// `NSAttributedString.boundingRect(options: .usesDeviceMetrics)` —
/// the actual pixel ink rect, not typographic advance. No clipping
/// at any size, with or without rotation.
struct HandwrittenLetter: View {
    let letter: String
    var size: CGFloat
    var weight: UIFont.Weight = .bold
    var color: Color = .redPen
    var rotation: Angle = .zero

    var body: some View {
        InkBoundsLabel.caveat(letter, size: size, weight: weight, color: color)
            .fixedSize()
            .rotationEffect(rotation)
    }
}

#Preview {
    VStack(spacing: 24) {
        HandwrittenText(text: "SCRIBBLD", size: 32)
        HandwrittenText(text: "Sharp. You got them.", size: 22)
            .frame(maxWidth: 220)
        HStack(spacing: 12) {
            ForEach(["A", "B", "D", "K", "R", "P"], id: \.self) { l in
                ZStack {
                    Circle().stroke(Color.redPen, lineWidth: 2)
                        .frame(width: 64, height: 64)
                    HandwrittenLetter(letter: l, size: 40)
                }
            }
        }
    }
    .padding()
    .background(Color.cream)
}
