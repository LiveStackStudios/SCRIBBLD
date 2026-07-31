import SwiftUI

/// Primitives for the "drawn forcefully and re-traced" look used by
/// the in-game Tic Tac Toe marks (X / O) and by the home/detail
/// illustration. Each diagonal of an X is a bundle of 3 parallel
/// wobbly strokes; each O is 3 concentric wobbly loops. The center
/// pass is full-opacity / thicker; outer passes are lighter / thinner.
///
/// Shapes (rather than ZStacks of Canvases) so SwiftUI `.trim` works
/// for the cell-drawn-in animation that fires when a mark is placed.

// MARK: - Parallel X

/// Both diagonals of an X, both offset perpendicular by `perpOffset`.
/// Three instances with offsets -spread, 0, +spread layered in a
/// ZStack form the multi-stroke X effect.
struct ParallelXShape: Shape {
    var seed: UInt64
    var perpOffset: CGFloat

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed: seed)
        let inset: CGFloat = 6
        let tl = CGPoint(x: rect.minX + inset, y: rect.minY + inset)
        let br = CGPoint(x: rect.maxX - inset, y: rect.maxY - inset)
        let tr = CGPoint(x: rect.maxX - inset, y: rect.minY + inset)
        let bl = CGPoint(x: rect.minX + inset, y: rect.maxY - inset)

        // Tiny center-miss jitter, same as the original HandDrawnX so
        // the diagonals don't intersect at the exact same point.
        let jx = rng.next(-1.2, 1.2)
        let jy = rng.next(-1.2, 1.2)

        let d1 = perpendicularEndpoints(
            from: tl,
            to: CGPoint(x: br.x + jx, y: br.y + jy)
        )
        let d2 = perpendicularEndpoints(
            from: tr,
            to: CGPoint(x: bl.x - jx, y: bl.y - jy)
        )

        var combined = Path()
        combined.addPath(HandDrawn.wobblyPath(
            from: d1.a, to: d1.b,
            wobble: 1.2, segmentLength: 9, rng: &rng
        ))
        combined.addPath(HandDrawn.wobblyPath(
            from: d2.a, to: d2.b,
            wobble: 1.2, segmentLength: 9, rng: &rng
        ))
        return combined
    }

    /// Shift the line A→B perpendicular to its direction by `perpOffset`.
    private func perpendicularEndpoints(from a: CGPoint, to b: CGPoint) -> (a: CGPoint, b: CGPoint) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = max(0.001, sqrt(dx * dx + dy * dy))
        let nx = -dy / len, ny = dx / len
        return (
            CGPoint(x: a.x + nx * perpOffset, y: a.y + ny * perpOffset),
            CGPoint(x: b.x + nx * perpOffset, y: b.y + ny * perpOffset)
        )
    }
}

// MARK: - Concentric O

/// Single wobbly circle with `expansion` added to the base radius.
/// Three instances with expansion -1, 0, +1 layered in a ZStack form
/// the multi-loop O effect.
struct ConcentricOShape: Shape {
    var seed: UInt64
    var expansion: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed: seed)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 8 + expansion
        let startDeg: CGFloat = -90 + rng.next(-12, 12)
        let sweep: CGFloat = 380 + rng.next(-15, 15)
        return HandDrawn.wobblyArc(
            center: center,
            radius: radius,
            startDeg: startDeg,
            endDeg: startDeg + sweep,
            wobble: 1.0,
            rng: &rng
        )
    }
}

// MARK: - View wrappers (3-layer ZStacks for the in-game marks)

struct MultiStrokeX: View {
    let seed: UInt64
    var color: Color = .inkBlue
    var lineWidth: CGFloat = 2.6
    /// Optional 0...1 draw-in progress so the same `.trim` animation
    /// the prior X used continues to work. Pass nil for fully drawn.
    var progress: Double? = nil
    /// Perpendicular spread between adjacent stroke passes.
    var spread: CGFloat = 1.5

    var body: some View {
        let p = progress ?? 1.0
        ZStack {
            ParallelXShape(seed: seed &+ 1, perpOffset: -spread)
                .trim(from: 0, to: p)
                .stroke(color.opacity(0.55),
                        style: SwiftUI.StrokeStyle(lineWidth: lineWidth * 0.65,
                                                    lineCap: .round, lineJoin: .round))
            ParallelXShape(seed: seed &+ 2, perpOffset: spread)
                .trim(from: 0, to: p)
                .stroke(color.opacity(0.55),
                        style: SwiftUI.StrokeStyle(lineWidth: lineWidth * 0.65,
                                                    lineCap: .round, lineJoin: .round))
            ParallelXShape(seed: seed, perpOffset: 0)
                .trim(from: 0, to: p)
                .stroke(color.opacity(0.95),
                        style: SwiftUI.StrokeStyle(lineWidth: lineWidth,
                                                    lineCap: .round, lineJoin: .round))
        }
    }
}

struct MultiStrokeO: View {
    let seed: UInt64
    var color: Color = .redPen
    var lineWidth: CGFloat = 2.6
    var progress: Double? = nil
    /// Radial spread between adjacent loop passes.
    var spread: CGFloat = 1.4

    var body: some View {
        let p = progress ?? 1.0
        ZStack {
            ConcentricOShape(seed: seed &+ 11, expansion: -spread)
                .trim(from: 0, to: p)
                .stroke(color.opacity(0.55),
                        style: SwiftUI.StrokeStyle(lineWidth: lineWidth * 0.65,
                                                    lineCap: .round, lineJoin: .round))
            ConcentricOShape(seed: seed &+ 13, expansion: spread)
                .trim(from: 0, to: p)
                .stroke(color.opacity(0.55),
                        style: SwiftUI.StrokeStyle(lineWidth: lineWidth * 0.65,
                                                    lineCap: .round, lineJoin: .round))
            ConcentricOShape(seed: seed, expansion: 0)
                .trim(from: 0, to: p)
                .stroke(color.opacity(0.95),
                        style: SwiftUI.StrokeStyle(lineWidth: lineWidth,
                                                    lineCap: .round, lineJoin: .round))
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 12) {
            MultiStrokeX(seed: 1).frame(width: 80, height: 80)
            MultiStrokeO(seed: 2).frame(width: 80, height: 80)
            MultiStrokeX(seed: 3).frame(width: 80, height: 80)
        }
        HStack(spacing: 12) {
            MultiStrokeO(seed: 4).frame(width: 80, height: 80)
            MultiStrokeX(seed: 5).frame(width: 80, height: 80)
            MultiStrokeO(seed: 6).frame(width: 80, height: 80)
        }
    }
    .padding()
    .background(Color.cream)
}
