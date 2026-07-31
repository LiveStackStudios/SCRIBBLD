import SwiftUI

/// Hand-drawn pencil-stroke circle. Drop-in replacement for
/// `Circle().stroke(...)` anywhere a circle should look sketched
/// rather than vector-perfect — Hangman keyboard keys, Stop! letter
/// randomizer, decorative outlines.
///
/// Build:
///  - Wobbly radial path (variable r along the arc).
///  - Stroke is intentionally drawn as a slight over-sweep
///    (≥ 365°) so the closing point overlaps the starting point a
///    little — the way you'd actually close a circle by hand.
///  - Wobble amplitude scales with radius so a 14pt key and a 110pt
///    letter circle both look proportionally sketched.
struct SketchCircle: Shape {
    var seed: UInt64 = 1
    /// Multiplier on the radial wobble. 1.0 = ≈ 4% of radius (visible
    /// at small sizes); bump to 1.5–2.0 for chunkier sketch feel.
    var wobbleScale: CGFloat = 1.0

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed: seed)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Inset so the stroke (rendered around the path) stays inside
        // the available rect rather than clipping at the bounds.
        let radius = (min(rect.width, rect.height) / 2) - 1
        // Sweep slightly more than 360° so the line clearly overlaps
        // where it closes — like a real pencil circle.
        let startDeg: CGFloat = -90 + rng.next(-12, 12)
        let sweep: CGFloat = 380 + rng.next(-10, 10)
        let endDeg = startDeg + sweep
        // Wobble proportional to radius so small circles still read
        // as sketched (a flat 1.0pt wobble vanishes on a 14pt key).
        let wobble = max(0.6, radius * 0.045) * wobbleScale
        return HandDrawn.wobblyArc(
            center: center,
            radius: radius,
            startDeg: startDeg,
            endDeg: endDeg,
            wobble: wobble,
            rng: &rng
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        // Side-by-side: vector circle (left) vs SketchCircle (right)
        ForEach([18, 30, 60, 120], id: \.self) { size in
            HStack(spacing: 24) {
                Circle()
                    .stroke(Color.inkBlue, lineWidth: 1.8)
                    .frame(width: CGFloat(size), height: CGFloat(size))
                SketchCircle(seed: UInt64(size))
                    .stroke(Color.inkBlue, lineWidth: 1.8)
                    .frame(width: CGFloat(size), height: CGFloat(size))
            }
        }
        Text("vector (left)  vs  sketched (right)")
            .font(.dmSans(11))
            .foregroundStyle(Color.softGray)
    }
    .padding()
    .background(Color.cream)
}
