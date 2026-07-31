import SwiftUI

/// A single hand-drawn pencil-shaded dot. Replaces `Path(ellipseIn:)`
/// filled with a flat gray, which reads as a digital UI dot and breaks
/// the sketchbook feel. This is the dot used in the Dots & Boxes grid
/// (and reusable anywhere we'd otherwise render `Circle().fill()` at
/// small sizes in the brand aesthetic).
///
/// The composition mimics what happens when you press a pencil down and
/// scribble a small filled circle:
///   1. A wobbly outer **outline** ring (slightly overdrawn arc).
///   2. Several overlapping **scribble arcs** inside at low opacity,
///      varying start/end angles so they layer into a denser interior.
///   3. A faint **center mark** where pencil pressure would peak.
///
/// `size` is the diameter; the view sizes itself to that frame with
/// `.fixedSize()` so it never gets stretched by an aspect ratio.
struct PencilDot: View {
    var size: CGFloat = 10
    var color: Color = Color(hex: "#8C8C7A")        // soft graphite gray
    var seed: UInt64 = 1

    var body: some View {
        Canvas { ctx, canvas in
            var rng = SeededRandom(seed: seed)
            let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
            let radius = min(canvas.width, canvas.height) / 2 - 1

            // 1. Outer wobbly ring — the "outline" of the dot. Slight
            //    over-sweep so the closing point overlaps, like a real
            //    pencil circle.
            let startDeg: CGFloat = -90 + rng.next(-15, 15)
            let endDeg: CGFloat = startDeg + 385 + rng.next(-10, 10)
            let ring = HandDrawn.wobblyArc(
                center: center,
                radius: radius,
                startDeg: startDeg,
                endDeg: endDeg,
                wobble: max(0.5, radius * 0.08),
                rng: &rng
            )
            ctx.stroke(
                ring,
                with: .color(color.opacity(0.95)),
                style: StrokeStyle(lineWidth: max(1.0, size * 0.10), lineCap: .round, lineJoin: .round)
            )

            // 2. Scribble fill — 4 overlapping wobbly arcs at slightly
            //    smaller radii, each starting at a random angle, layered
            //    at low opacity. Builds up the "shaded interior" look.
            for _ in 0..<4 {
                let innerR = radius * rng.next(0.35, 0.85)
                let sd: CGFloat = rng.next(-180, 180)
                let ed: CGFloat = sd + rng.next(180, 320)
                let arc = HandDrawn.wobblyArc(
                    center: CGPoint(
                        x: center.x + rng.next(-0.6, 0.6),
                        y: center.y + rng.next(-0.6, 0.6)
                    ),
                    radius: innerR,
                    startDeg: sd,
                    endDeg: ed,
                    wobble: max(0.4, innerR * 0.12),
                    rng: &rng
                )
                ctx.stroke(
                    arc,
                    with: .color(color.opacity(rng.next(0.30, 0.55))),
                    style: StrokeStyle(lineWidth: max(0.8, size * 0.08), lineCap: .round)
                )
            }

            // 3. Center pressure point — slightly darker spot where the
            //    pencil would have started or paused.
            let dot = Path(ellipseIn: CGRect(
                x: center.x - size * 0.10,
                y: center.y - size * 0.10,
                width: size * 0.20,
                height: size * 0.20
            ))
            ctx.fill(dot, with: .color(color.opacity(0.85)))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(0..<8, id: \.self) { i in
            PencilDot(size: 14, seed: UInt64(i + 1))
        }
    }
    .padding()
    .background(Color.cream)
}
