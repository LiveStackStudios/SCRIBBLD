import SwiftUI

/// Core rendering primitives that make every line, border, circle, and
/// shape in SCRIBBLD look hand-drawn rather than digital. Every entry
/// point takes a `seed` so the same UI element redraws the same way each
/// frame — only the things that should look "newly drawn" change.
enum HandDrawn {

    // MARK: - Stroke styles

    enum StrokeStyle {
        case pencil       // Graphite — soft, textured, dark gray
        case inkPen       // Ballpoint — confident ink-blue, slight endpoint bleed
        case fountainPen  // Variable width, expressive
        case marker       // Thick + slightly fuzzy
        case redPen       // Red — corrections, O marks, win lines

        var color: Color {
            switch self {
            case .pencil:       return Color(hex: "#2A2A2A")
            case .inkPen:       return Color(hex: "#1A365D")
            case .fountainPen:  return Color(hex: "#1A365D")
            case .marker:       return Color(hex: "#1A365D")
            case .redPen:       return Color(hex: "#C53030")
            }
        }

        var baseWidth: CGFloat {
            switch self {
            case .pencil:       return 1.8
            case .inkPen:       return 2.0
            case .fountainPen:  return 2.4
            case .marker:       return 3.2
            case .redPen:       return 2.2
            }
        }

        var baseOpacity: Double {
            switch self {
            case .pencil:       return 0.78
            case .inkPen:       return 0.92
            case .fountainPen:  return 0.95
            case .marker:       return 0.85
            case .redPen:       return 0.90
            }
        }
    }

    // MARK: - Corner styles

    enum CornerStyle {
        case crossover  // Lines extend past corner 2-4pt — sketch default
        case closed     // Lines meet with a tiny gap
        case rounded    // Short curved segment between sides — used for buttons
    }

    // MARK: - Primitives

    /// A single hand-drawn line, wobble + overshoot + endpoint bleed.
    static func line(
        from: CGPoint,
        to: CGPoint,
        style: StrokeStyle = .inkPen,
        wobble: CGFloat = 1.5,
        seed: UInt64 = 0
    ) -> some View {
        Canvas { context, _ in
            var rng = SeededRandom(seed: seed)
            let path = wobblyPath(from: from, to: to, wobble: wobble, rng: &rng)
            drawStrokedPath(path, style: style, context: context, rng: &rng)
        }
    }

    /// Hand-drawn rectangle made of 4 wobbly sides. Corners follow the
    /// chosen style. Pass the rect in the host view's local coordinate
    /// space (typically `CGRect(origin: .zero, size: geometry.size)`).
    static func rectangle(
        in rect: CGRect,
        style: StrokeStyle = .inkPen,
        cornerStyle: CornerStyle = .crossover,
        wobble: CGFloat = 0.9,
        seed: UInt64 = 0
    ) -> some View {
        Canvas { context, _ in
            var rng = SeededRandom(seed: seed)
            // Corner offsets per side
            let crossover: CGFloat = (cornerStyle == .crossover) ? 3 : 0
            let gap: CGFloat = (cornerStyle == .closed) ? rng.next(0.5, 1.5) : 0
            let radius: CGFloat = (cornerStyle == .rounded) ? 8 : 0

            // Defining endpoints with optional crossover
            let tl = rect.origin
            let tr = CGPoint(x: rect.maxX, y: rect.minY)
            let br = CGPoint(x: rect.maxX, y: rect.maxY)
            let bl = CGPoint(x: rect.minX, y: rect.maxY)

            func draw(_ a: CGPoint, _ b: CGPoint, _ extendA: CGFloat, _ extendB: CGFloat) {
                let dx = b.x - a.x
                let dy = b.y - a.y
                let len = max(sqrt(dx * dx + dy * dy), 0.001)
                let ux = dx / len, uy = dy / len
                let start = CGPoint(x: a.x - ux * extendA, y: a.y - uy * extendA)
                let end = CGPoint(x: b.x + ux * extendB, y: b.y + uy * extendB)
                let path = wobblyPath(from: start, to: end, wobble: wobble, rng: &rng)
                drawStrokedPath(path, style: style, context: context, rng: &rng)
            }

            switch cornerStyle {
            case .crossover:
                draw(tl, tr, crossover, crossover)
                draw(tr, br, crossover, crossover)
                draw(br, bl, crossover, crossover)
                draw(bl, tl, crossover, crossover)
            case .closed:
                draw(tl, tr, -gap, -gap)
                draw(tr, br, -gap, -gap)
                draw(br, bl, -gap, -gap)
                draw(bl, tl, -gap, -gap)
            case .rounded:
                // Sides shortened to leave room for the rounded join
                let r = radius
                draw(CGPoint(x: tl.x + r, y: tl.y), CGPoint(x: tr.x - r, y: tr.y), 0, 0)
                draw(CGPoint(x: tr.x, y: tr.y + r), CGPoint(x: br.x, y: br.y - r), 0, 0)
                draw(CGPoint(x: br.x - r, y: br.y), CGPoint(x: bl.x + r, y: bl.y), 0, 0)
                draw(CGPoint(x: bl.x, y: bl.y - r), CGPoint(x: tl.x, y: tl.y + r), 0, 0)

                // Approximate quarter-arcs with two wobbly lines each
                func arc(_ corner: CGPoint, _ dx: CGFloat, _ dy: CGFloat) {
                    let mid = CGPoint(x: corner.x + dx * r * 0.5, y: corner.y + dy * r * 0.5)
                    draw(CGPoint(x: corner.x + dx * r, y: corner.y),
                         CGPoint(x: mid.x, y: mid.y), 0, 0)
                    draw(CGPoint(x: mid.x, y: mid.y),
                         CGPoint(x: corner.x, y: corner.y + dy * r), 0, 0)
                }
                arc(tl,  1, 1)
                arc(tr, -1, 1)
                arc(br, -1, -1)
                arc(bl,  1, -1)
            }
        }
    }

    /// Hand-drawn circle — two overlapping arcs as humans actually draw.
    static func circle(
        in rect: CGRect,
        style: StrokeStyle = .inkPen,
        wobble: CGFloat = 1.0,
        seed: UInt64 = 0
    ) -> some View {
        Canvas { context, _ in
            var rng = SeededRandom(seed: seed)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2

            // Arc 1: roughly the top half plus overlap (≈ -10° to 175°)
            let startA: CGFloat = -10 + rng.next(-5, 5)
            let endA:   CGFloat = 175 + rng.next(-5, 5)
            let arc1 = wobblyArc(center: center, radius: radius,
                                 startDeg: startA, endDeg: endA,
                                 wobble: wobble, rng: &rng)
            drawStrokedPath(arc1, style: style, context: context, rng: &rng)

            // Arc 2: rest of the circle, with overlap at the top + tiny gap at bottom
            let startB: CGFloat = 170 + rng.next(-3, 3)
            let endB:   CGFloat = 350 + rng.next(-8, 8)
            let arc2 = wobblyArc(center: center, radius: radius,
                                 startDeg: startB, endDeg: endB,
                                 wobble: wobble, rng: &rng)
            drawStrokedPath(arc2, style: style, context: context, rng: &rng)
        }
    }

    /// Soft, irregular watercolor wash — 3-5 overlapping ellipses with low
    /// opacity. Always rendered _behind_ a stroked element, like real ink.
    static func wash(
        in rect: CGRect,
        color: Color,
        intensity: Double = 0.22,
        blobCount: Int = 4,
        seed: UInt64 = 0
    ) -> some View {
        Canvas { context, _ in
            var rng = SeededRandom(seed: seed)
            for _ in 0..<blobCount {
                let cx = rect.midX + rng.next(-rect.width * 0.18, rect.width * 0.18)
                let cy = rect.midY + rng.next(-rect.height * 0.18, rect.height * 0.18)
                let w = rect.width * rng.next(0.6, 1.1)
                let h = rect.height * rng.next(0.6, 1.1)
                let blobRect = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
                let opacity = intensity * rng.next(0.6, 1.0)
                context.fill(
                    Path(ellipseIn: blobRect),
                    with: .color(color.opacity(opacity))
                )
            }
            // Tiny darker pooling near a random edge
            let pool = CGRect(
                x: rect.minX + rng.next(0, rect.width * 0.6),
                y: rect.minY + rng.next(0, rect.height * 0.6),
                width: 6, height: 4
            )
            context.fill(Path(ellipseIn: pool), with: .color(color.opacity(intensity + 0.10)))
        }
    }

    // MARK: - Path generators (used by primitives and the public API)

    /// The core algorithm: a wobbly path between two points with smooth
    /// quadratic-curve interpolation between sample points + endpoint
    /// overshoot. Wobble varies _along_ the stroke, not as a single shift.
    static func wobblyPath(
        from: CGPoint,
        to: CGPoint,
        wobble: CGFloat = 1.5,
        segmentLength: CGFloat = 8,
        rng: inout SeededRandom
    ) -> Path {
        var path = Path()
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = max(sqrt(dx * dx + dy * dy), 0.001)
        let segments = max(2, Int(length / segmentLength))

        let startOffset = rng.next(-2, 2)
        let endOffset   = rng.next(-2, 2)
        let ux = dx / length
        let uy = dy / length
        // Perpendicular direction for wobble
        let px = -uy
        let py = ux

        // Random phase + frequency so each line wobbles differently
        let phase = rng.next(0, 6.28)
        let freq  = rng.next(1.5, 3.0)

        var points: [CGPoint] = []
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let lineX = from.x + dx * t
            let lineY = from.y + dy * t
            let attenuation = sin(t * .pi) // ends settle to true line
            let amount = wobble * sin(t * .pi * freq + phase) * attenuation * rng.next(0.6, 1.0)
            points.append(CGPoint(x: lineX + px * amount, y: lineY + py * amount))
        }

        points[0].x += ux * startOffset
        points[0].y += uy * startOffset
        let lastIdx = points.count - 1
        points[lastIdx].x += ux * endOffset
        points[lastIdx].y += uy * endOffset

        path.move(to: points[0])
        for i in 1..<points.count {
            let p1 = points[i - 1]
            let p2 = points[i]
            let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
            path.addQuadCurve(to: mid, control: p1)
        }
        path.addLine(to: points[lastIdx])
        return path
    }

    /// Wobbly arc between two angles (in degrees, measured from +x axis).
    static func wobblyArc(
        center: CGPoint,
        radius: CGFloat,
        startDeg: CGFloat,
        endDeg: CGFloat,
        wobble: CGFloat,
        rng: inout SeededRandom
    ) -> Path {
        var path = Path()
        let startRad = startDeg * .pi / 180
        let endRad = endDeg * .pi / 180
        let totalArc = endRad - startRad
        let arcLength = abs(totalArc) * radius
        let segmentLength: CGFloat = 6
        let segments = max(8, Int(arcLength / segmentLength))

        let phase = rng.next(0, 6.28)
        let freq  = rng.next(1.5, 3.0)

        var points: [CGPoint] = []
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let angle = startRad + totalArc * t
            let radialWobble = wobble * sin(t * .pi * freq + phase) * rng.next(0.5, 1.0)
            let r = radius + radialWobble
            let x = center.x + cos(angle) * r
            let y = center.y + sin(angle) * r
            points.append(CGPoint(x: x, y: y))
        }

        path.move(to: points[0])
        for i in 1..<points.count {
            let p1 = points[i - 1]
            let p2 = points[i]
            let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
            path.addQuadCurve(to: mid, control: p1)
        }
        path.addLine(to: points.last!)
        return path
    }

    // MARK: - Stroke rendering

    /// Draws a single wobbly path with style-specific texturing. Pencil
    /// gets a second offset stroke for graphite grain; pen styles get a
    /// tiny ink-bleed dot at each endpoint.
    static func drawStrokedPath(
        _ path: Path,
        style: StrokeStyle,
        context: GraphicsContext,
        rng: inout SeededRandom
    ) {
        let color = style.color
        let baseWidth = style.baseWidth
        let baseOpacity = style.baseOpacity

        // Main stroke
        context.stroke(
            path,
            with: .color(color.opacity(baseOpacity)),
            style: SwiftUI.StrokeStyle(
                lineWidth: baseWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )

        if style == .pencil {
            let offsetPath = path.applying(
                CGAffineTransform(translationX: rng.next(-0.5, 0.5),
                                  y: rng.next(-0.5, 0.5))
            )
            context.stroke(
                offsetPath,
                with: .color(color.opacity(0.35)),
                style: SwiftUI.StrokeStyle(lineWidth: baseWidth * 0.6, lineCap: .round)
            )
        }

        if style == .marker {
            // Slight outer fuzz — a wider, lower-opacity pass
            context.stroke(
                path,
                with: .color(color.opacity(baseOpacity * 0.35)),
                style: SwiftUI.StrokeStyle(lineWidth: baseWidth * 1.5, lineCap: .round)
            )
        }

        if style == .inkPen || style == .fountainPen || style == .redPen {
            // Endpoint bleed — small dot at both ends of the path
            if let cgFirst = path.cgPath.firstPoint, let cgLast = path.cgPath.lastPoint {
                let r1 = rng.next(0.6, 1.4)
                let r2 = rng.next(0.6, 1.4)
                context.fill(
                    Path(ellipseIn: CGRect(x: cgFirst.x - r1, y: cgFirst.y - r1,
                                            width: r1 * 2, height: r1 * 2)),
                    with: .color(color.opacity(baseOpacity * 0.7))
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: cgLast.x - r2, y: cgLast.y - r2,
                                            width: r2 * 2, height: r2 * 2)),
                    with: .color(color.opacity(baseOpacity * 0.7))
                )
            }
        }
    }
}

// MARK: - Seeded random

/// Deterministic LCG used by every hand-drawn element so wobbles stay
/// stable across redraws. Seed 0 falls back to a fixed magic so unseeded
/// callers still get reproducible-but-distinct output.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEADBEEF : seed
    }

    /// Returns a CGFloat in the half-open range [min, max).
    mutating func next(_ min: CGFloat, _ max: CGFloat) -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let normalized = CGFloat(state >> 33) / CGFloat(UInt32.max)
        return min + normalized * (max - min)
    }
}

// MARK: - String → stable seed (for per-element identity)

extension String {
    /// djb2 hash → stable seed. Same string always produces the same wobble.
    var stableSeed: UInt64 {
        var hash: UInt64 = 5381
        for byte in self.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return hash
    }
}

// MARK: - CGPath endpoint helpers (used for ink-bleed)

private extension CGPath {
    var firstPoint: CGPoint? {
        var result: CGPoint?
        applyWithBlock { elementPtr in
            guard result == nil else { return }
            let element = elementPtr.pointee
            switch element.type {
            case .moveToPoint:    result = element.points[0]
            case .addLineToPoint: result = element.points[0]
            case .addQuadCurveToPoint: result = element.points[1]
            case .addCurveToPoint: result = element.points[2]
            default: break
            }
        }
        return result
    }

    var lastPoint: CGPoint? {
        var result: CGPoint?
        applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            switch element.type {
            case .moveToPoint:         result = element.points[0]
            case .addLineToPoint:      result = element.points[0]
            case .addQuadCurveToPoint: result = element.points[1]
            case .addCurveToPoint:     result = element.points[2]
            default: break
            }
        }
        return result
    }
}
