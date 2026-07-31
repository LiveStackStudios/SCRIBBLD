import SwiftUI

struct DailyChallengeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView().ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Text("DAILY CHALLENGE")
                    .font(.dmSans(11, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(Color.inkBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(appState.dailyChallenge.title)
                    .font(.caveat(36, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal)

                GameIllustration(game: appState.dailyChallenge.game)
                    .frame(height: 200)
                    .padding(.horizontal, 30)

                NavigationLink {
                    GameDetailView(game: appState.dailyChallenge.game)
                } label: {
                    Text("Play Today's Game")
                        .font(.caveat(22, weight: .bold))
                        .foregroundStyle(Color.cream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.inkBlue)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                BannerAdView(adUnitID: AdConfig.Banner.home)
            }
            .padding()
        }
        .navigationTitle("Daily Challenge")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { DailyChallengeView() }
        .environmentObject(AppState())
        .environmentObject(StoreManager())
}
