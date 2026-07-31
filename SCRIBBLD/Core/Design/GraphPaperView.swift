import SwiftUI

/// Cream paper with a faint square grid. Lines are drawn straight at
/// 20pt spacing — the wobble in the brand comes from the strokes drawn
/// ON the paper, not the paper itself.
struct GraphPaperView: View {
    var spacing: CGFloat = 20
    var lineColor: Color = .gridGray
    var lineOpacity: Double = 0.3
    var lineWidth: CGFloat = 0.6
    var background: Color = .cream

    var body: some View {
        Canvas { context, size in
            var path = Path()

            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(
                path,
                with: .color(lineColor.opacity(lineOpacity)),
                lineWidth: lineWidth
            )
        }
        .background(background)
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

struct DotGridView: View {
    var spacing: CGFloat = 20
    var dotColor: Color = .gridGray
    var dotOpacity: Double = 0.55
    var dotRadius: CGFloat = 1.0
    var background: Color = .cream

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = spacing
            while y <= size.height {
                var x: CGFloat = spacing
                while x <= size.width {
                    let rect = CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(dotColor.opacity(dotOpacity))
                    )
                    x += spacing
                }
                y += spacing
            }
        }
        .background(background)
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

#Preview("Graph paper") {
    GraphPaperView()
        .frame(width: 360, height: 640)
}
