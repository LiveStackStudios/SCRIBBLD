import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    /// Global language pref — the EN/ES toggle in the top bar writes
    /// here, the rest of the app reads `AppLanguage.current` which
    /// resolves to this value.
    @AppStorage(AppLanguage.storageKey) private var langRaw: String = ""
    private var lang: GameLanguage { GameLanguage.resolve(from: langRaw) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cream.ignoresSafeArea()
                GraphPaperView().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        topBar
                        greeting
                        gameGrid
                        NavigationLink(value: HomeRoute.dailyChallenge) {
                            DailyChallengeCard(challenge: appState.dailyChallenge)
                        }
                        .buttonStyle(.plain)
                        BannerAdView(adUnitID: AdConfig.Banner.home)
                            .padding(.top, 8)
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xs)
                }
            }
            .navigationDestination(for: GameType.self) { game in
                // Sketching and Sand Snake have no mode or difficulty to pick,
                // so they open directly — same routing as the Games tab.
                switch game {
                case .sketching: SketchingView()
                case .sandSnake: SandSnakeView()
                default:         GameDetailView(game: game)
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .dailyChallenge: DailyChallengeView()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var topBar: some View {
        // Three-column layout — language pill on the left, wordmark
        // centered, streak chip on the right. Equal side widths so the
        // wordmark stays perfectly centered.
        HStack(spacing: 8) {
            languagePill
                .frame(width: 70, alignment: .leading)
            Spacer()
            ScribbldWordmark(size: 28)
                .overlay(alignment: .bottom) {
                    PencilLineView(color: .inkBlue, lineWidth: 1.4, amplitude: 1, wavelength: 18, seed: 4)
                        .frame(width: 130, height: 4)
                        .offset(y: 6)
                }
            Spacer()
            HStack(spacing: 4) {
                Text("\u{1F525}").font(.system(size: 18))
                InkBoundsLabel.caveat(
                    "\(appState.streak.currentStreak)",
                    size: 20, weight: .bold, color: .redPen
                )
                .fixedSize()
            }
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.top, 4)
    }

    /// Global EN/ES toggle, available on every Home visit. The pill
    /// shows the language you'll switch TO on tap (so when currently
    /// English, it reads "ES"). Single tap writes the new value to
    /// @AppStorage — every view observing the pref auto-updates.
    private var languagePill: some View {
        Button {
            HapticEngine.light()
            let next: GameLanguage = (lang == .spanish) ? .english : .spanish
            AppLanguage.set(next)
        } label: {
            Text(lang == .spanish ? "EN" : "ES")
                .font(.dmSans(11, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Color.cream)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    PencilFilledSurface(
                        color: .inkBlue,
                        cornerRadius: 12,
                        seed: 9091
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(lang == .spanish ? "Switch to English" : "Cambiar a español")
    }

    private var greeting: some View {
        Text(appState.greeting)
            .font(.caveat(34, weight: .bold))
            .foregroundStyle(Color.inkBlue)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.trailing, 6)
            .fixedSize(horizontal: false, vertical: true)
            .zIndex(1)
    }

    private var gameGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(GameType.allCases) { game in
                NavigationLink(value: game) {
                    GameCardView(game: game)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

enum HomeRoute: Hashable {
    case dailyChallenge
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(StoreManager())
}
