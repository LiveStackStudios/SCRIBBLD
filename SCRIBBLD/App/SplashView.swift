import SwiftUI

struct SplashView: View {
    private let fullWord = "SCRIBBLD"
    @State private var revealed = 0
    @State private var taglineVisible = false

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView(lineOpacity: 0.22).ignoresSafeArea()

            VStack(spacing: 22) {
                // Two-layer ink-bounds label so the full-width slot
                // reserves space and the visible prefix pops in via
                // `.animation` on `revealed`. Using InkBoundsLabel
                // (not Text) so the trailing `D` isn't clipped at 56pt.
                ZStack(alignment: .leading) {
                    InkBoundsLabel.caveat(fullWord, size: 56, color: .clear)
                        .fixedSize()
                    InkBoundsLabel.caveat(
                        String(fullWord.prefix(revealed)),
                        size: 56,
                        color: .inkBlue
                    )
                    .fixedSize()
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottom) {
                    PencilLineView(color: .redPen, lineWidth: 2.5, amplitude: 1.6, wavelength: 26)
                        .frame(width: CGFloat(revealed) / CGFloat(fullWord.count) * 220, height: 8)
                        .animation(.easeInOut(duration: 0.22), value: revealed)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: revealed)

                Text("Play like it's analog.")
                    .font(.scribbldBody(size: 14))
                    .foregroundStyle(Color.softGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.trailing, 4)
                    .fixedSize(horizontal: false, vertical: true)
                    .zIndex(1)
                    .opacity(taglineVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: taglineVisible)
            }
            .padding(.horizontal, 24)
        }
        .task {
            for i in 1...fullWord.count {
                try? await Task.sleep(nanoseconds: 110_000_000)
                revealed = i
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
            taglineVisible = true
        }
    }
}

#Preview {
    SplashView()
}
