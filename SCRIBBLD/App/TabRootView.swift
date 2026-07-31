import SwiftUI

enum AppTab: Hashable {
    case home, games, friends, profile
}

struct TabRootView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            GamesTabView()
                .tabItem { Label("Games", systemImage: "gamecontroller") }
                .badge(2)
                .tag(AppTab.games)

            FriendsTabView()
                .tabItem { Label("Friends", systemImage: "person.2") }
                .badge(1)
                .tag(AppTab.friends)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
                .tag(AppTab.profile)
        }
        .tint(.inkBlue)
        .background(Color.cream)
    }
}

struct GamesTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.cream.ignoresSafeArea()
                GraphPaperView().ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text("All Games")
                            .font(.scribbldTitle(size: 36))
                            .foregroundStyle(Color.inkBlue)
                            .padding(.horizontal)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                            ForEach(GameType.allCases) { game in
                                // Sketching is not a "game" — skip the detail screen
                                // (with mode/difficulty pickers) and go straight to the
                                // canvas.
                                if game == .sketching {
                                    NavigationLink {
                                        SketchingView()
                                    } label: {
                                        GameCardView(game: game)
                                    }
                                    .buttonStyle(.plain)
                                } else if game == .sandSnake {
                                    // Solo run — no mode/difficulty to pick,
                                    // so skip the detail screen like Sketching.
                                    NavigationLink {
                                        SandSnakeView()
                                    } label: {
                                        GameCardView(game: game)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    NavigationLink(value: game) {
                                        GameCardView(game: game)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top)
                }
            }
            .navigationDestination(for: GameType.self) { game in
                GameDetailView(game: game)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// FriendsTabView lives in Features/Friends/FriendsTabView.swift now.

#Preview {
    TabRootView()
        .environmentObject(AppState())
        .environmentObject(StoreManager())
        .environmentObject(AuthService())
        .environmentObject(FriendsService())
}
