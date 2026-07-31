import SwiftUI

/// Renders a Shape with the multi-pass overlay that makes it read as a
/// colored-pencil stroke rather than a flat pen line. Each pass takes
/// the same Shape so SwiftUI's `.trim(from:to:)` draw-in animation
/// stays in sync across passes — the X/O marks still animate cleanly.
///
/// Composition is intentional:
///  - **Main pass** is the visible colored line (full opacity, full width).
///  - **Grain pass** is the same line offset by a sub-pixel amount, half
///    opacity, slightly narrower — this is what gives the "graphite/wax
///    grain" feel. Without it the stroke reads as a calligraphy pen.
///  - **Soft halo** is a wider, very low-opacity pass that fakes the
///    paper bleed colored pencils leave around a heavy stroke.
///
/// All three passes share the trim progress so a half-drawn stroke
/// shows half of each layer, preserving the in-progress look.
struct ColoredPencilStroke<S: Shape>: View {
    let shape: S
    var color: Color
    var lineWidth: CGFloat = 3
    /// Optional draw-in progress (0...1). Pass nil to render fully.
    var progress: Double? = nil
    /// Bump if a single screen has two adjacent strokes whose grain
    /// happens to align — varies the offset deterministically per seed.
    var seed: UInt64 = 1

    var body: some View {
        let p = progress ?? 1.0
        let offsetX = grainOffsetX
        let offsetY = grainOffsetY

        ZStack {
            // Soft halo — drawn first, sits behind the main stroke.
            // Visibility was bumped from 0.18 → 0.38 — the prior value
            // didn't read as pencil texture on device, just looked
            // like a regular pen line.
            shape
                .trim(from: 0, to: p)
                .stroke(color.opacity(0.38),
                        style: StrokeStyle(lineWidth: lineWidth * 1.8, lineCap: .round, lineJoin: .round))
                .blur(radius: 2.0)

            // Grain pass — offset duplicate at substantial opacity so
            // the parallel-stroke layering reads as graphite/wax grain.
            shape
                .trim(from: 0, to: p)
                .stroke(color.opacity(0.70),
                        style: StrokeStyle(lineWidth: lineWidth * 0.85, lineCap: .round, lineJoin: .round))
                .offset(x: offsetX, y: offsetY)

            // Main pass — the colored line itself, almost full opacity.
            shape
                .trim(from: 0, to: p)
                .stroke(color.opacity(0.95),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        // Keeps the trim animation continuous if the parent animates `progress`.
        .animation(nil, value: seed)
        .accessibilityHidden(true)
    }

    private var grainOffsetX: CGFloat {
        var rng = SeededRandom(seed: seed)
        return rng.next(-0.7, 0.7)
    }

    private var grainOffsetY: CGFloat {
        var rng = SeededRandom(seed: seed &+ 7)
        return rng.next(-0.7, 0.7)
    }
}

#Preview {
    VStack(spacing: 30) {
        // Solid stroke vs colored pencil — side-by-side comparison
        HStack(spacing: 24) {
            HandDrawnX(seed: 11)
                .stroke(Color.inkBlue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 90, height: 90)
            ColoredPencilStroke(shape: HandDrawnX(seed: 11),
                                color: .inkBlue, lineWidth: 3, seed: 11)
                .frame(width: 90, height: 90)
        }
        HStack(spacing: 24) {
            HandDrawnO(seed: 17)
                .stroke(Color.redPen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 90, height: 90)
            ColoredPencilStroke(shape: HandDrawnO(seed: 17),
                                color: .redPen, lineWidth: 3, seed: 17)
                .frame(width: 90, height: 90)
        }
        Text("flat stroke (left)  vs  colored pencil (right)")
            .font(.dmSans(11))
            .foregroundStyle(Color.softGray)
    }
    .padding()
    .background(Color.cream)
}
