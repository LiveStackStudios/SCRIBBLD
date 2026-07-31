import SwiftUI

struct PencilLineView: View {
    var color: Color = .inkBlue
    var lineWidth: CGFloat = 2
    var amplitude: CGFloat = 1.4
    var wavelength: CGFloat = 22
    var seed: UInt64 = 1

    var body: some View {
        PencilLineShape(amplitude: amplitude, wavelength: wavelength, seed: seed)
            .stroke(color, style: StrokeStyle(
                lineWidth: lineWidth,
                lineCap: .round,
                lineJoin: .round
            ))
            .frame(height: max(amplitude * 2 + lineWidth * 2, 6))
            .accessibilityHidden(true)
    }
}

struct PencilLineShape: Shape {
    var amplitude: CGFloat = 1.4
    var wavelength: CGFloat = 22
    var seed: UInt64 = 1

    func path(in rect: CGRect) -> Path {
        let width = max(rect.width, 1)
        let midY = rect.midY
        var rng = SeededRNG(seed: seed)
        let segments = max(Int(width / 4), 12)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: midY))

        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let x = rect.minX + t * width
            let wave = sin((x / wavelength) * .pi * 2) * amplitude
            let jitter = (rng.nextUnitFloat() - 0.5) * (amplitude * 0.8)
            path.addLine(to: CGPoint(x: x, y: midY + wave + jitter))
        }

        return path
    }
}

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func nextUnitFloat() -> CGFloat {
        CGFloat(next() % 10_000) / 10_000.0
    }
}

#Preview("Pencil lines") {
    VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 6) {
            Text("Final Score: 4,850 pts")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.inkBlue)
            PencilLineView(color: .redPen, seed: 7)
                .frame(width: 220)
        }

        VStack(alignment: .leading, spacing: 6) {
            Text("Correct Answers: 24/25")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.inkBlue)
            PencilLineView(color: .redPen, seed: 13)
                .frame(width: 220)
        }

        VStack(alignment: .leading, spacing: 6) {
            Text("Profile")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(Color.inkBlue)
            PencilLineView(color: .redPen, lineWidth: 2.5, seed: 21)
                .frame(width: 110)
        }
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Color.cream)
}
