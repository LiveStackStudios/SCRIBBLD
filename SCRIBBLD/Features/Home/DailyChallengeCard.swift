import SwiftUI

struct DailyChallengeCard: View {
    let challenge: DailyChallenge
    @AppStorage(AppLanguage.storageKey) private var langRaw: String = ""
    private var lang: GameLanguage { GameLanguage.resolve(from: langRaw) }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text(lang == .spanish ? "RETO DIARIO" : "DAILY CHALLENGE")
                .font(.dmSans(10, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(Color.inkBlue)
                .lineLimit(1)

            HStack(spacing: 12) {
                Text("\(lang == .spanish ? "Reto" : "Challenge"): \(challenge.title)")
                    .font(.caveat(22, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .padding(.trailing, 4)
                    .fixedSize(horizontal: false, vertical: true)
                    .zIndex(1)
                Spacer(minLength: 0)
                TileTrio()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.55))
        .sketchBorder(color: .redPen, lineWidth: 1.6, cornerRadius: 10, jitter: 1.6, dash: [7, 4], seed: 707)
    }
}

private struct TileTrio: View {
    var body: some View {
        HStack(spacing: 5) {
            ForEach([("1", -8.0), ("5", 0.0), ("2", 8.0), ("3", -4.0)], id: \.0) { num, rot in
                Text(num)
                    .font(.dmSans(13, weight: .semibold))
                    .foregroundStyle(Color.inkBlue)
                    .frame(width: 22, height: 22)
                    .background(Color.cream)
                    .sketchBorder(color: .inkBlue, lineWidth: 1, cornerRadius: 4, jitter: 0.4, seed: UInt64(abs(Int(rot)) + 1))
                    .rotationEffect(.degrees(rot))
            }
        }
    }
}

#Preview {
    DailyChallengeCard(challenge: DailyChallenge.forToday())
        .padding()
        .background(GraphPaperView())
}
