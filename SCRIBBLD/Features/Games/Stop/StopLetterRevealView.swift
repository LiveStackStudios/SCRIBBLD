import SwiftUI

struct StopLetterRevealView: View {
    @ObservedObject var vm: StopGameViewModel

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView().ignoresSafeArea()
            VStack(spacing: Spacing.xl) {
                Text(vm.letterRevealPhrase)
                    .font(.caveat(28, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, Spacing.lg)
                ZStack {
                    // Outer pencil-drawn circle, replacing the prior
                    // vector-perfect Circle().stroke(). Wobble scaled
                    // up so the sketched feel reads at 220pt.
                    SketchCircle(seed: 101, wobbleScale: 1.4)
                        .stroke(Color.redPen,
                                style: SwiftUI.StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .frame(width: 220, height: 220)
                    // Inner dashed pencil ring — same hand-drawn build,
                    // dashed stroke style for the broken-line look.
                    SketchCircle(seed: 102, wobbleScale: 1.1)
                        .stroke(Color.redPen.opacity(0.45),
                                style: SwiftUI.StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [5, 3]))
                        .frame(width: 196, height: 196)
                    HandwrittenLetter(
                        letter: String(vm.displayedLetter),
                        size: 96,
                        color: .redPen,
                        rotation: .degrees(-3)
                    )
                    .transition(.scale.combined(with: .opacity))
                    .id(vm.displayedLetter)
                }
                .scaleEffect(vm.letterRevealing ? 1.0 : 1.1)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: vm.displayedLetter)
                if !vm.letterRevealing {
                    Text(vm.languageHint)
                        .font(.caveat(24, weight: .bold))
                        .foregroundStyle(Color.inkBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, Spacing.lg)
                }
            }
        }
    }
}

#Preview {
    StopLetterRevealView(vm: StopGameViewModel())
}
