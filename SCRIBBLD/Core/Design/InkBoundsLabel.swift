import SwiftUI
import UIKit

/// SwiftUI `Text` sizes itself to a font's *advance-width* bounds — the
/// distance the layout pen moves after drawing each glyph. For Caveat's
/// `D` (and other display/script fonts), the **visible ink** extends past
/// that advance-width: the tail curves into space the layout engine
/// doesn't reserve. The right edge of the rendering buffer then clips
/// the glyph. Trailing padding cannot fix this — it expands the parent
/// frame, not the Text's own internal rendering rect.
///
/// `InkBoundsLabel` wraps a `UILabel` with `clipsToBounds = false` and
/// sizes the view using `NSAttributedString.boundingRect` with
/// `.usesDeviceMetrics`, which returns **image bounds (ink)** instead of
/// typographic bounds. The result: every glyph's visible pixels are
/// inside the view's reported size, no surprise clipping. Use this for
/// short labels in handwritten fonts (wordmarks, single-letter displays,
/// flourished headlines) where clipping the tail of the last glyph is
/// the difference between "looks right" and "looks broken."
struct InkBoundsLabel: UIViewRepresentable {
    let text: String
    var font: UIFont
    var color: UIColor
    /// Extra slack added to the measured size on every side. Caveat's
    /// boldest glyphs (D, R, K, exclamation tails) overshoot even the
    /// `.usesDeviceMetrics` ink rect by a few sub-pixels at large
    /// font sizes, and the SwiftUI host's compositing layer can clip
    /// at the reported size. Slack of ~15% of the font size is
    /// enough to keep the worst overshoots inside the rendered
    /// buffer at any practical size, while staying invisible because
    /// it sits past the ink and never participates in visible layout.
    var slack: CGFloat = 6
    /// Shrink the text when the proposed width is narrower than the measured
    /// ink. `1` (the default) never shrinks — the label reports its natural
    /// ink size and overflows a tight parent rather than scaling.
    ///
    /// Set this below 1 for text whose length isn't known in advance
    /// (headlines that vary by outcome and language). It's the ink-safe
    /// equivalent of `Text`'s `.minimumScaleFactor`.
    var minimumScaleFactor: CGFloat = 1

    private var shrinks: Bool { minimumScaleFactor < 1 }

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        label.clipsToBounds = false           // ← critical
        label.textAlignment = .center
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.text = text
        uiView.font = font
        uiView.textColor = color
        uiView.adjustsFontSizeToFitWidth = shrinks
        uiView.minimumScaleFactor = shrinks ? minimumScaleFactor : 0
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        // .usesDeviceMetrics returns IMAGE BOUNDS (the actual pixel
        // bounding rect of every rendered glyph) instead of typographic
        // bounds. This is what makes the D's tail count.
        let bounds = attributed.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude,
                         height: CGFloat.greatestFiniteMagnitude),
            options: [.usesDeviceMetrics, .usesFontLeading, .usesLineFragmentOrigin],
            context: nil
        )
        let natural = CGSize(
            width: ceil(bounds.width) + slack,
            height: ceil(bounds.height) + slack
        )
        // When shrinking is allowed and the parent is narrower than the ink,
        // accept the parent's width so UILabel scales the font down to fit.
        // Height stays at the un-shrunk measurement: it's harmless slack (the
        // label doesn't clip) and reserving it avoids a vertical clip if the
        // scale lands differently than we predict.
        if shrinks,
           let proposed = proposal.width,
           proposed.isFinite, proposed > 0,
           natural.width > proposed {
            return CGSize(width: proposed, height: natural.height)
        }
        return natural
    }
}

/// Convenience constructor that reads the font from the
/// SwiftUI design system (`Font.caveat(_:weight:)`).
extension InkBoundsLabel {
    static func caveat(
        _ text: String,
        size: CGFloat,
        weight: UIFont.Weight = .bold,
        color: Color = .inkBlue,
        minimumScaleFactor: CGFloat = 1
    ) -> InkBoundsLabel {
        // Caveat ships as a variable font; iOS picks the right weight
        // axis when we ask for the family name + weight via descriptor.
        let descriptor = UIFontDescriptor(name: "Caveat", size: size)
            .addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: weight]
            ])
        let font = UIFont(descriptor: descriptor, size: size)
        // Slack scales with font size — at 96pt the R's leg overshoot
        // is much wider than at 18pt. 15% of the font size covers
        // every glyph we've seen in production.
        let slack = max(6, size * 0.15)
        return InkBoundsLabel(
            text: text,
            font: font,
            color: UIColor(color),
            slack: slack,
            minimumScaleFactor: minimumScaleFactor
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        // Side-by-side: SwiftUI Text vs InkBoundsLabel for the same text.
        // The SwiftUI version clips the D's tail; the ink-bounds version
        // doesn't. Put both inside a tight container so you can see it.
        ForEach([18, 28, 40, 56], id: \.self) { size in
            HStack(spacing: 24) {
                Text("SCRIBBLD")
                    .font(.caveat(CGFloat(size), weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                    .background(Color.redPen.opacity(0.08)) // shows the rendering box

                InkBoundsLabel.caveat("SCRIBBLD", size: CGFloat(size), color: .inkBlue)
                    .background(Color.inkGreen.opacity(0.10))
            }
        }
    }
    .padding(24)
    .background(Color.cream)
}
