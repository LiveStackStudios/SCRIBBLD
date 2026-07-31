import SwiftUI

// MARK: - Border modifier

/// Wraps any view with a hand-drawn rectangle outline. Use this in place
/// of `.border()` / `.overlay(RoundedRectangle...)` everywhere in the app.
extension View {
    func handDrawnBorder(
        style: HandDrawn.StrokeStyle = .inkPen,
        cornerStyle: HandDrawn.CornerStyle = .crossover,
        wobble: CGFloat = 0.9,
        seed: UInt64 = 0
    ) -> some View {
        self.overlay(
            GeometryReader { geo in
                HandDrawn.rectangle(
                    in: CGRect(origin: .zero, size: geo.size),
                    style: style,
                    cornerStyle: cornerStyle,
                    wobble: wobble,
                    seed: seed
                )
                .allowsHitTesting(false)
            }
        )
    }
}

// MARK: - Paper backgrounds

enum PaperKind {
    case graph    // 24pt × 24pt grid, default for most screens
    case lined    // Horizontal rules every 28pt + red left margin
    case dotted   // Bullet-journal style — dot grid
    case blank    // Just cream, no pattern
}

extension View {
    func paperBackground(_ kind: PaperKind = .graph) -> some View {
        self.background(
            PaperBackgroundView(kind: kind)
                .allowsHitTesting(false)
        )
    }
}

struct PaperBackgroundView: View {
    let kind: PaperKind

    var body: some View {
        ZStack {
            Color.cream
            Canvas { context, size in
                switch kind {
                case .graph:    drawGraph(context, size: size)
                case .lined:    drawLined(context, size: size)
                case .dotted:   drawDotted(context, size: size)
                case .blank:    break
                }
            }
        }
        .drawingGroup() // Cache as a bitmap — static background, zero re-render cost
    }

    private func drawGraph(_ context: GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 24
        var rng = SeededRandom(seed: 7)
        let inkColor = HandDrawn.StrokeStyle.pencil.color.opacity(0.18)

        for x in stride(from: spacing, to: size.width, by: spacing) {
            let path = HandDrawn.wobblyPath(
                from: CGPoint(x: x, y: 0),
                to: CGPoint(x: x, y: size.height),
                wobble: 0.3,
                segmentLength: 24,
                rng: &rng
            )
            context.stroke(path, with: .color(inkColor), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        }
        for y in stride(from: spacing, to: size.height, by: spacing) {
            let path = HandDrawn.wobblyPath(
                from: CGPoint(x: 0, y: y),
                to: CGPoint(x: size.width, y: y),
                wobble: 0.3,
                segmentLength: 24,
                rng: &rng
            )
            context.stroke(path, with: .color(inkColor), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        }
    }

    private func drawLined(_ context: GraphicsContext, size: CGSize) {
        let lineSpacing: CGFloat = 28
        var rng = SeededRandom(seed: 11)
        let lineColor = Color.gridGray.opacity(0.4)
        let marginColor = Color.redPen.opacity(0.3)

        // Horizontal rules
        for y in stride(from: lineSpacing, to: size.height, by: lineSpacing) {
            let path = HandDrawn.wobblyPath(
                from: CGPoint(x: 6, y: y),
                to: CGPoint(x: size.width - 6, y: y),
                wobble: 0.4,
                segmentLength: 32,
                rng: &rng
            )
            context.stroke(path, with: .color(lineColor), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        }

        // Red vertical margin at x = 36
        let marginX: CGFloat = 36
        let marginPath = HandDrawn.wobblyPath(
            from: CGPoint(x: marginX, y: 0),
            to: CGPoint(x: marginX, y: size.height),
            wobble: 0.5,
            segmentLength: 50,
            rng: &rng
        )
        context.stroke(marginPath, with: .color(marginColor), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
    }

    private func drawDotted(_ context: GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 22
        let color = Color.gridGray.opacity(0.45)
        var rng = SeededRandom(seed: 19)
        for x in stride(from: spacing, to: size.width, by: spacing) {
            for y in stride(from: spacing, to: size.height, by: spacing) {
                let jx = rng.next(-0.4, 0.4)
                let jy = rng.next(-0.4, 0.4)
                let dot = CGRect(x: x + jx - 1, y: y + jy - 1, width: 2, height: 2)
                context.fill(Path(ellipseIn: dot), with: .color(color))
            }
        }
    }
}

// MARK: - Button modifier

extension View {
    /// Hand-drawn "card button" shell: a sketchy rectangle + padding +
    /// optional fill. Pass a stable per-button seed.
    func handDrawnButton(
        fill: Color = .clear,
        stroke: HandDrawn.StrokeStyle = .inkPen,
        cornerStyle: HandDrawn.CornerStyle = .rounded,
        seed: UInt64 = 0
    ) -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(fill)
            .handDrawnBorder(style: stroke, cornerStyle: cornerStyle, seed: seed)
    }
}

// MARK: - Text styling

extension View {
    /// Handwritten labels (titles, scores, callouts). Caveat Bold.
    func handWritten(_ size: CGFloat, weight: Font.Weight = .bold) -> some View {
        self.font(.custom("Caveat", size: size).weight(weight))
    }

    /// Typed labels (small captions, meta). DM Sans.
    func typed(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(.custom("DMSans", size: size).weight(weight))
    }
}
