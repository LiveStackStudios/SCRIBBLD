import SwiftUI

// MARK: - X mark (Shape — animatable via .trim and SwiftUI .animation)

/// Hand-drawn Tic Tac Toe "X". Path = two wobbly diagonal segments
/// joined end-to-end so a single `.trim(from:to:)` on the stroke gives a
/// "first diagonal draws, then second diagonal draws" effect.
///
/// Use as: `HandDrawnX(seed: …).stroke(color, style: …)` and pass the
/// `progress` (0→1) to drive `.trim`.
struct HandDrawnX: Shape {
    var seed: UInt64 = 1

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed: seed)
        let inset: CGFloat = 6
        let tl = CGPoint(x: rect.minX + inset, y: rect.minY + inset)
        let br = CGPoint(x: rect.maxX - inset, y: rect.maxY - inset)
        let tr = CGPoint(x: rect.maxX - inset, y: rect.minY + inset)
        let bl = CGPoint(x: rect.minX + inset, y: rect.maxY - inset)
        // Center crossing miss by 1-2pt (humans don't hit center exactly)
        let jx = rng.next(-1.5, 1.5)
        let jy = rng.next(-1.5, 1.5)

        // Bumped wobble + shorter segment length so the "drawn by hand"
        // quality reads at game-cell size (≈ 80–100pt diagonal). At the
        // old 1.6/12 the wobble was 3% of length — invisible on device.
        let path1 = HandDrawn.wobblyPath(
            from: tl,
            to: CGPoint(x: br.x + jx, y: br.y + jy),
            wobble: 3.5, segmentLength: 8, rng: &rng
        )
        let path2 = HandDrawn.wobblyPath(
            from: tr,
            to: CGPoint(x: bl.x - jx, y: bl.y - jy),
            wobble: 3.5, segmentLength: 8, rng: &rng
        )

        var combined = Path()
        combined.addPath(path1)
        combined.addPath(path2)
        return combined
    }
}

// MARK: - O mark (Shape — animatable via .trim)

/// Hand-drawn Tic Tac Toe "O" — one wobbly arc that overshoots its
/// closure (humans never close a circle exactly).
struct HandDrawnO: Shape {
    var seed: UInt64 = 1

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed: seed)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 8
        let startDeg: CGFloat = -90 + rng.next(-12, 12)
        let sweep: CGFloat = 380 + rng.next(-15, 15)
        let endDeg = startDeg + sweep
        return HandDrawn.wobblyArc(
            center: center,
            radius: radius,
            startDeg: startDeg,
            endDeg: endDeg,
            wobble: 2.5,
            rng: &rng
        )
    }
}

// MARK: - Tally marks

/// One cluster = up to 5 strokes. Pass `count` and the view chunks it into
/// clusters automatically, with hand-drawn 4 verticals + diagonal 5th.
struct HandDrawnTally: View {
    var count: Int
    var color: Color = HandDrawn.StrokeStyle.inkPen.color
    var lineWidth: CGFloat = 1.8
    var seed: UInt64 = 21

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: seed)
            let strokeHeight = size.height
            let strokeSpacing: CGFloat = 5
            let clusterGap: CGFloat = 12
            var x: CGFloat = 1
            var remaining = max(0, count)

            while remaining > 0 {
                let inCluster = min(5, remaining)
                // 4 vertical strokes
                let baseStrokes = min(inCluster, 4)
                for i in 0..<baseStrokes {
                    let top = CGPoint(x: x + CGFloat(i) * strokeSpacing + rng.next(-0.3, 0.3),
                                      y: 1 + rng.next(-1, 1))
                    let bottom = CGPoint(x: x + CGFloat(i) * strokeSpacing + rng.next(-0.3, 0.3),
                                         y: strokeHeight - 1 + rng.next(-1, 1))
                    let p = HandDrawn.wobblyPath(from: top, to: bottom, wobble: 0.6, rng: &rng)
                    ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
                // Diagonal 5th
                if inCluster == 5 {
                    let start = CGPoint(x: x - 2, y: strokeHeight - 1 + rng.next(-0.8, 0.8))
                    let end = CGPoint(x: x + CGFloat(3) * strokeSpacing + 3, y: 1 + rng.next(-0.8, 0.8))
                    let p = HandDrawn.wobblyPath(from: start, to: end, wobble: 0.8, rng: &rng)
                    ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
                x += CGFloat(baseStrokes - 1) * strokeSpacing + clusterGap
                remaining -= inCluster
            }
        }
        .frame(width: tallyWidth, height: 18)
    }

    private var tallyWidth: CGFloat {
        let clusters = (count + 4) / 5
        let lastClusterCount = count % 5 == 0 ? 5 : count % 5
        let firstClustersWidth = CGFloat(max(0, clusters - 1)) * (4 * 5 + 12)
        let lastClusterWidth = CGFloat(max(1, lastClusterCount) - 1) * 5 + 10
        return firstClustersWidth + lastClusterWidth
    }
}

// MARK: - Strikethrough

struct HandDrawnStrikethrough: View {
    var color: Color = HandDrawn.StrokeStyle.redPen.color
    var lineWidth: CGFloat = 1.6
    var seed: UInt64 = 23

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: seed)
            let start = CGPoint(x: -2 + rng.next(-1, 1), y: size.height - 2 + rng.next(-1, 1))
            let end = CGPoint(x: size.width + 2 + rng.next(-1, 1), y: 2 + rng.next(-1, 1))
            let path = HandDrawn.wobblyPath(from: start, to: end, wobble: 0.7, rng: &rng)
            ctx.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }
}

// MARK: - Cross-hatch fill

/// Diagonal parallel strokes filling a region — used for shading the
/// Hangman gallows base and top beam.
struct HandDrawnCrossHatch: View {
    var color: Color = HandDrawn.StrokeStyle.inkPen.color
    var spacing: CGFloat = 5
    var angle: CGFloat = 45      // degrees
    var lineWidth: CGFloat = 1.2
    var seed: UInt64 = 31

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: seed)
            let rad = angle * .pi / 180
            let dx = cos(rad), dy = sin(rad)
            // Extend the bounding box so diagonals cover corners
            let diag = sqrt(size.width * size.width + size.height * size.height)
            var t: CGFloat = -diag
            while t < diag {
                // Start outside the box, end outside the box
                let cx = size.width / 2 + t * dy
                let cy = size.height / 2 - t * dx
                let start = CGPoint(x: cx - dx * diag, y: cy - dy * diag)
                let end = CGPoint(x: cx + dx * diag, y: cy + dy * diag)
                let p = HandDrawn.wobblyPath(from: start, to: end, wobble: 0.5, rng: &rng)
                let clipped = p
                // Clip to bounds: stroke and let Canvas clip naturally
                ctx.stroke(clipped, with: .color(color.opacity(rng.next(0.55, 0.85))),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                t += spacing + rng.next(-0.6, 0.6)
            }
        }
        .clipShape(Rectangle())
    }
}

// MARK: - Checkmark

struct HandDrawnCheckmark: View {
    var color: Color = HandDrawn.StrokeStyle.inkPen.color
    var lineWidth: CGFloat = 2.0
    var seed: UInt64 = 41

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: seed)
            let dip = CGPoint(x: size.width * 0.4, y: size.height * 0.75)
            let start = CGPoint(x: size.width * 0.1, y: size.height * 0.5)
            let end = CGPoint(x: size.width * 0.95, y: size.height * 0.15)
            let p1 = HandDrawn.wobblyPath(from: start, to: dip, wobble: 0.6, rng: &rng)
            let p2 = HandDrawn.wobblyPath(from: dip, to: end, wobble: 0.6, rng: &rng)
            ctx.stroke(p1, with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            ctx.stroke(p2, with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }
}

// MARK: - Hand-drawn watercolor wash (View wrapper around HandDrawn.wash)

struct HandDrawnWash: View {
    var color: Color
    var intensity: Double = 0.22
    var blobs: Int = 4
    var seed: UInt64 = 51

    var body: some View {
        GeometryReader { geo in
            HandDrawn.wash(
                in: CGRect(origin: .zero, size: geo.size),
                color: color,
                intensity: intensity,
                blobCount: blobs,
                seed: seed
            )
        }
    }
}
