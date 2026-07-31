import SwiftUI

/// Hand-drawn rectangle border drawn as a Shape with smooth quadratic
/// curves through wobbled control points. Shape (rather than Canvas) so
/// the border can compose with SwiftUI animation if ever needed and so
/// the strokes look smooth-wobbly rather than jaggy-segmented.
struct SketchBorderModifier: ViewModifier {
    var color: Color = .inkBlue
    var lineWidth: CGFloat = 1.5
    var cornerRadius: CGFloat = Radius.card
    var jitter: CGFloat = 1.2
    var dash: [CGFloat] = []
    var seed: UInt64 = 42

    func body(content: Content) -> some View {
        content
            .overlay(
                SketchBorderShape(
                    cornerRadius: cornerRadius,
                    jitter: jitter,
                    seed: seed
                )
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: dash
                    )
                )
            )
    }
}

struct SketchBorderShape: Shape {
    var cornerRadius: CGFloat = Radius.card
    var jitter: CGFloat = 1.2
    var seed: UInt64 = 42

    func path(in rect: CGRect) -> Path {
        var rng = SeededRNG(seed: seed)

        func wobble() -> CGFloat {
            (rng.nextUnitFloat() - 0.5) * jitter * 2
        }

        let r = min(cornerRadius, min(rect.width, rect.height) / 2)

        let topLeft     = CGPoint(x: rect.minX + r + wobble(),  y: rect.minY + wobble())
        let topRight    = CGPoint(x: rect.maxX - r + wobble(),  y: rect.minY + wobble())
        let rightTop    = CGPoint(x: rect.maxX + wobble(),       y: rect.minY + r + wobble())
        let rightBottom = CGPoint(x: rect.maxX + wobble(),       y: rect.maxY - r + wobble())
        let bottomRight = CGPoint(x: rect.maxX - r + wobble(),  y: rect.maxY + wobble())
        let bottomLeft  = CGPoint(x: rect.minX + r + wobble(),  y: rect.maxY + wobble())
        let leftBottom  = CGPoint(x: rect.minX + wobble(),       y: rect.maxY - r + wobble())
        let leftTop     = CGPoint(x: rect.minX + wobble(),       y: rect.minY + r + wobble())

        var path = Path()
        path.move(to: topLeft)

        let topMid = CGPoint(
            x: (topLeft.x + topRight.x) / 2 + wobble(),
            y: (topLeft.y + topRight.y) / 2 + wobble()
        )
        path.addQuadCurve(to: topRight, control: topMid)

        path.addQuadCurve(
            to: rightTop,
            control: CGPoint(x: rect.maxX + wobble(), y: rect.minY + wobble())
        )

        let rightMid = CGPoint(
            x: (rightTop.x + rightBottom.x) / 2 + wobble(),
            y: (rightTop.y + rightBottom.y) / 2 + wobble()
        )
        path.addQuadCurve(to: rightBottom, control: rightMid)

        path.addQuadCurve(
            to: bottomRight,
            control: CGPoint(x: rect.maxX + wobble(), y: rect.maxY + wobble())
        )

        let bottomMid = CGPoint(
            x: (bottomRight.x + bottomLeft.x) / 2 + wobble(),
            y: (bottomRight.y + bottomLeft.y) / 2 + wobble()
        )
        path.addQuadCurve(to: bottomLeft, control: bottomMid)

        path.addQuadCurve(
            to: leftBottom,
            control: CGPoint(x: rect.minX + wobble(), y: rect.maxY + wobble())
        )

        let leftMid = CGPoint(
            x: (leftBottom.x + leftTop.x) / 2 + wobble(),
            y: (leftBottom.y + leftTop.y) / 2 + wobble()
        )
        path.addQuadCurve(to: leftTop, control: leftMid)

        path.addQuadCurve(
            to: topLeft,
            control: CGPoint(x: rect.minX + wobble(), y: rect.minY + wobble())
        )

        path.closeSubpath()
        return path
    }
}

extension View {
    func sketchBorder(
        color: Color = .inkBlue,
        lineWidth: CGFloat = 1.5,
        cornerRadius: CGFloat = Radius.card,
        jitter: CGFloat = 1.2,
        dash: [CGFloat] = [],
        seed: UInt64 = 42
    ) -> some View {
        modifier(SketchBorderModifier(
            color: color,
            lineWidth: lineWidth,
            cornerRadius: cornerRadius,
            jitter: jitter,
            dash: dash,
            seed: seed
        ))
    }
}
