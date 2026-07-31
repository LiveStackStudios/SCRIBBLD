import SwiftUI
import PencilKit

enum SketchBrush: String, CaseIterable, Identifiable {
    case pencil, calligraphy, carbon, chalk, inkPen, marker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pencil:      return "Pencil"
        case .calligraphy: return "Calligraphy"
        case .carbon:      return "Carbon"
        case .chalk:       return "Chalk"
        case .inkPen:      return "Ink Pen"
        case .marker:      return "Marker"
        }
    }

    /// Free in the V1 spec.
    /// Spanish names are the ones an artist would actually use, not literal
    /// translations — "Carboncillo" is the drawing medium, "Rotulador" the
    /// marker pen.
    func title(in language: GameLanguage) -> String {
        guard language == .spanish else { return title }
        switch self {
        case .pencil:      return "Lápiz"
        case .calligraphy: return "Caligrafía"
        case .carbon:      return "Carboncillo"
        case .chalk:       return "Tiza"
        case .inkPen:      return "Pluma"
        case .marker:      return "Rotulador"
        }
    }

    var isFree: Bool { self == .pencil || self == .inkPen }

    /// Maps to the richest PKInk types available on iOS 17+.
    func tool(color: UIColor, width: CGFloat) -> PKTool {
        let ink: PKInk
        let resolvedWidth: CGFloat
        switch self {
        case .pencil:
            ink = PKInk(.pencil, color: color)
            resolvedWidth = max(2, width)
        case .calligraphy:
            ink = PKInk(.fountainPen, color: color)
            resolvedWidth = max(4, width)
        case .carbon:
            ink = PKInk(.crayon, color: color)
            resolvedWidth = max(5, width + 1)
        case .chalk:
            ink = PKInk(.watercolor, color: color.withAlphaComponent(0.7))
            resolvedWidth = max(10, width + 4)
        case .inkPen:
            ink = PKInk(.pen, color: color)
            resolvedWidth = max(2, width)
        case .marker:
            ink = PKInk(.marker, color: color.withAlphaComponent(0.85))
            resolvedWidth = max(8, width + 2)
        }
        return PKInkingTool(ink: ink, width: resolvedWidth)
    }

    /// A small representative stroke for the brush chip, drawn with Canvas
    /// so the chip visually previews the brush's character.
    func strokePreview(color: Color) -> some View {
        BrushStrokePreview(brush: self, color: color)
    }
}

struct BrushStrokePreview: View {
    let brush: SketchBrush
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            switch brush {
            case .pencil:      drawPencil(ctx, size: size)
            case .calligraphy: drawCalligraphy(ctx, size: size)
            case .carbon:      drawCarbon(ctx, size: size)
            case .chalk:       drawChalk(ctx, size: size)
            case .inkPen:      drawInkPen(ctx, size: size)
            case .marker:      drawMarker(ctx, size: size)
            }
        }
    }

    private var ink: Color { color }
    private func wave(samples: Int = 24, amplitude: CGFloat = 6, in size: CGSize) -> Path {
        var p = Path()
        let pad: CGFloat = 6
        let usable = size.width - pad * 2
        let midY = size.height / 2
        for i in 0...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let x = pad + t * usable
            let y = midY + sin(t * .pi * 2.2) * amplitude
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
            else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        return p
    }

    private func drawPencil(_ ctx: GraphicsContext, size: CGSize) {
        let p = wave(amplitude: 4, in: size)
        ctx.stroke(p, with: .color(ink.opacity(0.8)),
                   style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
    }
    private func drawCalligraphy(_ ctx: GraphicsContext, size: CGSize) {
        // Italic-style 'g' inspired mark.
        var p = Path()
        let midX = size.width / 2
        let midY = size.height / 2
        p.move(to: CGPoint(x: midX - 10, y: midY - 6))
        p.addQuadCurve(to: CGPoint(x: midX + 6, y: midY + 6),
                       control: CGPoint(x: midX + 10, y: midY - 14))
        p.addQuadCurve(to: CGPoint(x: midX - 4, y: midY + 10),
                       control: CGPoint(x: midX + 2, y: midY + 14))
        ctx.stroke(p, with: .color(ink),
                   style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
    }
    private func drawCarbon(_ ctx: GraphicsContext, size: CGSize) {
        // Dense crosshatch scribble.
        var p = Path()
        let midY = size.height / 2
        for i in 0..<8 {
            let x1 = 4 + CGFloat(i) * 4
            let y1 = midY - 6 + CGFloat(i % 2) * 2
            p.move(to: CGPoint(x: x1, y: y1))
            p.addLine(to: CGPoint(x: x1 + 12, y: midY + 6))
        }
        ctx.stroke(p, with: .color(ink.opacity(0.85)),
                   style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }
    private func drawChalk(_ ctx: GraphicsContext, size: CGSize) {
        // Soft cloud-like swatch.
        for i in 0..<3 {
            let rect = CGRect(
                x: 6 + CGFloat(i) * 6,
                y: size.height / 2 - 6 + CGFloat(i) * 1.4,
                width: 22, height: 12
            )
            ctx.fill(Path(ellipseIn: rect), with: .color(ink.opacity(0.18)))
        }
    }
    private func drawInkPen(_ ctx: GraphicsContext, size: CGSize) {
        let p = wave(amplitude: 5, in: size)
        ctx.stroke(p, with: .color(ink),
                   style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
    }
    private func drawMarker(_ ctx: GraphicsContext, size: CGSize) {
        // Wide rectangular swatch.
        let rect = CGRect(x: 6, y: size.height / 2 - 6, width: size.width - 12, height: 12)
        ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(ink.opacity(0.55)))
    }
}

enum SketchPaletteColor: String, CaseIterable, Identifiable {
    case deepInkBlue, redPen, forestGreen, burntSienna, charcoal, gold, softLavender

    var id: String { rawValue }
    var title: String {
        switch self {
        case .deepInkBlue:  return "Deep Ink\nBlue"
        case .redPen:       return "Red Pen"
        case .forestGreen:  return "Forest\nGreen"
        case .burntSienna:  return "Burnt\nSienna"
        case .charcoal:     return "Charcoal"
        case .gold:         return "Gold"
        case .softLavender: return "Soft\nLavender"
        }
    }

    /// Line breaks are placed to match the two-line label slot in the swatch
    /// row, so the Spanish names wrap at the same point the English ones do.
    func title(in language: GameLanguage) -> String {
        guard language == .spanish else { return title }
        switch self {
        case .deepInkBlue:  return "Azul\nTinta"
        case .redPen:       return "Rojo"
        case .forestGreen:  return "Verde\nBosque"
        case .burntSienna:  return "Siena\nTostada"
        case .charcoal:     return "Carbón"
        case .gold:         return "Dorado"
        case .softLavender: return "Lavanda\nSuave"
        }
    }

    var isFree: Bool { self == .deepInkBlue || self == .redPen }

    var color: Color {
        switch self {
        case .deepInkBlue:  return Color.inkBlue
        case .redPen:       return Color.redPen
        case .forestGreen:  return Color.inkGreen
        case .burntSienna:  return Color(hex: "#8B4513")
        case .charcoal:     return Color(hex: "#36454F")
        case .gold:         return Color.goldAccent
        case .softLavender: return Color(hex: "#B8A9C9")
        }
    }
}
