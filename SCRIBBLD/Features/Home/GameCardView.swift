import SwiftUI

struct GameCardView: View {
    let game: GameType
    var compact: Bool = false

    var body: some View {
        // Center alignment on the VStack + .multilineTextAlignment(.center)
        // on text so longer titles like "Dots and Boxes" sit centered
        // under the illustration instead of hugging the left edge.
        VStack(alignment: .center, spacing: 8) {
            GameIllustration(game: game)
                .frame(maxWidth: .infinity)
                .frame(height: compact ? 80 : 100)
            Text(game.title)
                .font(.caveat(20, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .padding(.trailing, 4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(game.blurb)
                .font(.dmSans(11, weight: .regular))
                .foregroundStyle(Color.softGray)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .top)
        .background(Color.white.opacity(0.65))
        .sketchBorder(color: .inkBlue, lineWidth: 1.3, cornerRadius: Radius.card, seed: UInt64(game.rawValue.hashValue & 0xFFFF))
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        ForEach(GameType.allCases.prefix(4)) { GameCardView(game: $0) }
    }
    .padding()
    .background(GraphPaperView())
}
