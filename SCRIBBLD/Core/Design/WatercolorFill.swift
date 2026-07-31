import SwiftUI

/// Watercolor wash: overlapping rounded rects + Gaussian blur to mimic
/// soft pigment bleed. The blur is what makes it read as wet ink rather
/// than flat color.
struct WatercolorFill: View {
    var color: Color
    var intensity: Double = 0.18
    var blobs: Int = 3
    var seed: UInt64 = 99

    var body: some View {
        Canvas { context, size in
            var rng = SeededRNG(seed: seed)
            for _ in 0..<blobs {
                let w = size.width * CGFloat(0.6 + rng.nextUnitFloat() * 0.5)
                let h = size.height * CGFloat(0.55 + rng.nextUnitFloat() * 0.55)
                let cx = size.width * CGFloat(0.2 + rng.nextUnitFloat() * 0.6)
                let cy = size.height * CGFloat(0.2 + rng.nextUnitFloat() * 0.6)
                let rect = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
                let blob = Path(roundedRect: rect, cornerRadius: min(w, h) / 2)
                let opacity = intensity * (0.6 + rng.nextUnitFloat() * 0.7)
                context.fill(blob, with: .color(color.opacity(opacity)))
            }
        }
        .blur(radius: 6)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct InkSplashWash: View {
    var color: Color
    var seed: UInt64 = 3

    var body: some View {
        Canvas { context, size in
            var rng = SeededRNG(seed: seed)
            for _ in 0..<14 {
                let r = CGFloat(2 + rng.nextUnitFloat() * 8)
                let x = size.width * CGFloat(rng.nextUnitFloat())
                let y = size.height * CGFloat(rng.nextUnitFloat())
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                let opacity = 0.10 + Double(rng.nextUnitFloat()) * 0.25
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Watercolor wash") {
    ZStack {
        Color.cream
        WatercolorFill(color: .inkBlue, intensity: 0.20, seed: 4)
            .frame(width: 260, height: 220)
            .offset(x: -70, y: -120)
        WatercolorFill(color: .redPen, intensity: 0.20, seed: 17)
            .frame(width: 260, height: 220)
            .offset(x: 80, y: 110)
    }
    .frame(width: 360, height: 480)
    .clipped()
}
