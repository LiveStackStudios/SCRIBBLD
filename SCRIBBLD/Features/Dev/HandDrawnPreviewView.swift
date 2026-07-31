import SwiftUI

/// Visual test bench for every HandDrawn primitive. Open from Settings →
/// About → "Hand-drawn preview" to sign off the look before screens are
/// migrated.
struct HandDrawnPreviewView: View {
    @State private var animatedProgress: Double = 0
    @State private var paperKind: PaperKind = .graph

    var body: some View {
        ZStack {
            PaperBackgroundView(kind: paperKind).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    paperSwitcher
                    section("Strokes — five styles, same line") { strokeStyles }
                    section("Wobbly lines — varying wobble") { wobbleScale }
                    section("Rectangles — three corner styles") { rectangles }
                    section("Hand-drawn circles") { circles }
                    section("Tally marks") { tallies }
                    section("Tic Tac Toe marks") { xoMarks }
                    section("Strikethrough on letters") { strikethroughRow }
                    section("Cross-hatch fill") { crossHatch }
                    section("Watercolor washes") { washes }
                    section("Checkmarks (Ink Pro feature list)") { checkmarks }
                    section("Button shells") { buttons }
                }
                .padding(20)
            }
        }
        .navigationTitle("Hand-Drawn Preview")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            animatedProgress = 0
            withAnimation(.easeOut(duration: 0.36)) { animatedProgress = 1 }
        }
    }

    // MARK: - Layout helpers

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HandDrawn preview")
                .handWritten(34)
                .foregroundStyle(Color.inkBlue)
            Text("Every primitive in isolation. Wobbles are deterministic per seed — relaunch the app and they redraw identically.")
                .typed(13)
                .foregroundStyle(Color.softGray)
        }
    }

    private var paperSwitcher: some View {
        HStack(spacing: 8) {
            ForEach([PaperKind.graph, .lined, .dotted, .blank], id: \.self) { kind in
                let on = (paperKind == kind)
                Text(label(for: kind))
                    .typed(12, weight: on ? .semibold : .regular)
                    .foregroundStyle(on ? Color.cream : Color.inkBlue)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(on ? Color.inkBlue : Color.white.opacity(0.7))
                    .clipShape(Capsule())
                    .onTapGesture { paperKind = kind }
            }
        }
    }

    private func label(for kind: PaperKind) -> String {
        switch kind {
        case .graph:   return "Graph"
        case .lined:   return "Lined"
        case .dotted:  return "Dotted"
        case .blank:   return "Blank"
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .typed(10, weight: .semibold)
                .tracking(1.5)
                .foregroundStyle(Color.softGray)
            content()
                .padding(14)
                .background(Color.white.opacity(0.7))
                .handDrawnBorder(style: .pencil, cornerStyle: .crossover, seed: title.stableSeed)
        }
    }

    // MARK: - Section content

    private var strokeStyles: some View {
        let styles: [(String, HandDrawn.StrokeStyle)] = [
            ("Pencil",      .pencil),
            ("Ink Pen",     .inkPen),
            ("Fountain Pen",.fountainPen),
            ("Marker",      .marker),
            ("Red Pen",     .redPen)
        ]
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(styles.enumerated()), id: \.offset) { idx, item in
                HStack {
                    Text(item.0).typed(12).foregroundStyle(Color.inkBlue).frame(width: 100, alignment: .leading)
                    HandDrawn.line(
                        from: CGPoint(x: 0, y: 12),
                        to: CGPoint(x: 200, y: 12),
                        style: item.1,
                        seed: UInt64(idx + 1) * 7
                    )
                    .frame(width: 220, height: 24)
                }
            }
        }
    }

    private var wobbleScale: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array([0.3, 0.8, 1.5, 2.5, 4.0].enumerated()), id: \.offset) { idx, w in
                HStack {
                    Text(String(format: "wobble %.1f", w))
                        .typed(12).foregroundStyle(Color.softGray).frame(width: 100, alignment: .leading)
                    HandDrawn.line(
                        from: CGPoint(x: 0, y: 12),
                        to: CGPoint(x: 220, y: 12),
                        style: .inkPen,
                        wobble: CGFloat(w),
                        seed: UInt64(idx + 1) * 13
                    )
                    .frame(width: 240, height: 24)
                }
            }
        }
    }

    private var rectangles: some View {
        let styles: [(String, HandDrawn.CornerStyle)] = [
            ("crossover", .crossover),
            ("closed",    .closed),
            ("rounded",   .rounded)
        ]
        return HStack(spacing: 12) {
            ForEach(Array(styles.enumerated()), id: \.offset) { idx, item in
                VStack(spacing: 6) {
                    Color.clear
                        .frame(height: 70)
                        .handDrawnBorder(style: .inkPen, cornerStyle: item.1, seed: UInt64(idx + 1) * 19)
                    Text(item.0).typed(10).foregroundStyle(Color.softGray)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var circles: some View {
        HStack(spacing: 18) {
            ForEach(Array([UInt64](1...4).enumerated()), id: \.offset) { _, seed in
                HandDrawn.circle(
                    in: CGRect(x: 0, y: 0, width: 56, height: 56),
                    style: .inkPen,
                    seed: seed * 31
                )
                .frame(width: 56, height: 56)
            }
            HandDrawn.circle(
                in: CGRect(x: 0, y: 0, width: 56, height: 56),
                style: .redPen,
                seed: 99
            )
            .frame(width: 56, height: 56)
        }
    }

    private var tallies: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach([3, 7, 14, 23], id: \.self) { count in
                HStack {
                    Text("\(count)").typed(12).foregroundStyle(Color.inkBlue).frame(width: 30, alignment: .leading)
                    HandDrawnTally(count: count, seed: UInt64(count) * 51)
                }
            }
        }
    }

    private var xoMarks: some View {
        HStack(spacing: 20) {
            ForEach(Array([UInt64](1...3).enumerated()), id: \.offset) { _, seed in
                HandDrawnX(seed: seed * 7)
                    .trim(from: 0, to: animatedProgress)
                    .stroke(Color.inkBlue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 56, height: 56)
            }
            ForEach(Array([UInt64](1...3).enumerated()), id: \.offset) { _, seed in
                HandDrawnO(seed: seed * 11)
                    .trim(from: 0, to: animatedProgress)
                    .stroke(Color.redPen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 56, height: 56)
            }
        }
    }

    private var strikethroughRow: some View {
        HStack(spacing: 18) {
            ForEach(["E", "I", "O", "U", "X", "Z"], id: \.self) { letter in
                ZStack {
                    Text(letter).typed(20, weight: .bold).foregroundStyle(Color.inkBlue)
                    HandDrawnStrikethrough(seed: UInt64(letter.unicodeScalars.first?.value ?? 1) * 17)
                        .frame(width: 28, height: 28)
                }
                .frame(width: 28, height: 28)
            }
        }
    }

    private var crossHatch: some View {
        HStack(spacing: 16) {
            HandDrawnCrossHatch(seed: 71)
                .frame(width: 120, height: 60)
                .background(Color.cream)
            HandDrawnCrossHatch(spacing: 7, angle: -45, seed: 73)
                .frame(width: 120, height: 60)
                .background(Color.cream)
        }
    }

    private var washes: some View {
        HStack(spacing: 12) {
            HandDrawnWash(color: .inkBlue, intensity: 0.25, seed: 81)
                .frame(height: 80)
            HandDrawnWash(color: .redPen, intensity: 0.25, seed: 83)
                .frame(height: 80)
            HandDrawnWash(color: .goldAccent, intensity: 0.28, seed: 85)
                .frame(height: 80)
        }
    }

    private var checkmarks: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(["UNLIMITED SKETCHBOOKS", "EXCLUSIVE BRUSHES", "CLOUD SYNC", "PRIORITY SUPPORT"], id: \.self) { line in
                HStack(spacing: 8) {
                    HandDrawnCheckmark(seed: line.stableSeed)
                        .frame(width: 20, height: 20)
                    Text(line).typed(12, weight: .semibold).foregroundStyle(Color.inkBlue)
                }
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Text("Start Game")
                .handWritten(20)
                .foregroundStyle(Color.cream)
                .handDrawnButton(fill: Color.inkBlue, stroke: .inkPen, cornerStyle: .rounded, seed: 91)
            Text("End Game")
                .handWritten(18)
                .foregroundStyle(Color.inkBlue)
                .handDrawnButton(fill: Color.white.opacity(0.5), stroke: .inkPen, cornerStyle: .crossover, seed: 93)
            Text("¡ STOP !")
                .handWritten(22)
                .foregroundStyle(Color.cream)
                .handDrawnButton(fill: Color.redPen, stroke: .marker, cornerStyle: .rounded, seed: 95)
        }
    }
}

#Preview {
    NavigationStack { HandDrawnPreviewView() }
}
