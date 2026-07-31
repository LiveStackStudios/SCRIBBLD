import SwiftUI

/// Dev-only screen used to verify the Foundation layer (Step 1 of the build order).
/// Renders GraphPaperView, PencilLineView, SketchBorderModifier, and WatercolorFill
/// together so the look-and-feel can be reviewed before screens are built.
struct FoundationShowcaseView: View {
    var body: some View {
        ZStack {
            GraphPaperView()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    graphPaperSection
                    pencilLineSection
                    sketchBorderSection
                    watercolorSection
                    combinedSection
                }
                .padding(20)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SCRIBBLD")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(Color.inkBlue)
            Text("Foundation layer · Step 1")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Color.softGray)
            PencilLineView(color: .redPen, lineWidth: 2.5, seed: 99)
                .frame(width: 140)
        }
    }

    private var graphPaperSection: some View {
        sectionCard(title: "GraphPaperView") {
            ZStack {
                GraphPaperView()
                Text("20pt grid · gridGray @ 30%")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.softGray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.cream.opacity(0.85))
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var pencilLineSection: some View {
        sectionCard(title: "PencilLineView") {
            VStack(alignment: .leading, spacing: 14) {
                labeledRow("Final Score: 4,850 pts", lineColor: .redPen, seed: 3)
                labeledRow("Correct Answers: 24/25", lineColor: .redPen, seed: 8)
                labeledRow("Game Time: 12:38", lineColor: .inkBlue, seed: 12)
            }
        }
    }

    private func labeledRow(_ label: String, lineColor: Color, seed: UInt64) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.inkBlue)
            PencilLineView(color: lineColor, seed: seed)
                .frame(width: 220)
        }
    }

    private var sketchBorderSection: some View {
        sectionCard(title: "SketchBorderModifier") {
            VStack(spacing: 14) {
                Text("Tic Tac Toe")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Color.inkBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(Color.white.opacity(0.5))
                    .sketchBorder(color: .inkBlue, seed: 22)

                Text("DAILY CHALLENGE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Color.inkBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(Color.white.opacity(0.5))
                    .sketchBorder(color: .redPen, lineWidth: 2, dash: [6, 4], seed: 35)
            }
        }
    }

    private var watercolorSection: some View {
        sectionCard(title: "WatercolorFill") {
            ZStack {
                Color.cream
                WatercolorFill(color: .inkBlue, intensity: 0.22, seed: 4)
                    .frame(width: 220, height: 160)
                    .offset(x: -60, y: -30)
                WatercolorFill(color: .redPen, intensity: 0.22, seed: 17)
                    .frame(width: 220, height: 160)
                    .offset(x: 70, y: 40)

                VStack(spacing: 0) {
                    Text("Sharp.")
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .foregroundStyle(Color.inkBlue)
                    Text("You got them.")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(Color.inkBlue)
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var combinedSection: some View {
        sectionCard(title: "Combined sample") {
            HStack(spacing: 12) {
                boxFill(label: "ME", color: .inkBlue, seed: 1)
                boxFill(label: "ME", color: .inkBlue, seed: 2)
                boxFill(label: "T", color: .redPen, seed: 3)
                boxFill(label: "T", color: .redPen, seed: 4)
                boxFill(label: "ME", color: .inkBlue, seed: 5)
            }
            .padding(.vertical, 8)
        }
    }

    private func boxFill(label: String, color: Color, seed: UInt64) -> some View {
        ZStack {
            WatercolorFill(color: color, intensity: 0.30, seed: seed)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 48, height: 48)
        .sketchBorder(color: color, lineWidth: 1, cornerRadius: 4, seed: seed + 50)
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Color.softGray)
            content()
        }
        .padding(16)
        .background(Color.cream.opacity(0.85))
        .sketchBorder(color: .lightLine, lineWidth: 1.2, jitter: 0.6, seed: UInt64(title.count) * 7)
    }
}

#Preview("Foundation showcase") {
    FoundationShowcaseView()
}
