import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var auth: AuthService
    @State private var showSettings = false
    @State private var presentSignIn = false

    private var language: GameLanguage { AppLanguage.current }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cream.ignoresSafeArea()
                GraphPaperView().ignoresSafeArea().allowsHitTesting(false)

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        topBar
                        identityRow
                        if !auth.isSignedIn { signInPrompt }
                        stampsSection
                        statsSection
                        streakSection
                        if auth.isSignedIn { signOutButton }
                        BannerAdView(adUnitID: AdConfig.Banner.home)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, 4)
                    .padding(.bottom, 32)
                    // Hard upper bound on row width so nothing can
                    // sneak past the safe area edges, even with weird
                    // localizations or long display names.
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $presentSignIn) {
                NavigationStack { SignInView().environmentObject(auth) }
            }
        }
    }

    // MARK: - Top bar (matches other screens — wordmark + chrome icons)

    private var topBar: some View {
        HStack(alignment: .center, spacing: 8) {
            ScribbldWordmark(size: 24)
            Spacer(minLength: 0)
            Button {
                HapticEngine.light()
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.inkBlue)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Identity row

    private var identityRow: some View {
        HStack(spacing: 14) {
            StampSeal(initials: initials)
                .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.caveat(28, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .truncationMode(.tail)
                Text(memberSinceText)
                    .font(.dmSans(13))
                    .foregroundStyle(Color.redPen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .truncationMode(.tail)
            }
            // Constrain the right side so a long display name can't
            // push siblings off-screen. minWidth: 0 lets it shrink.
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        // The whole row is one safe-area-bounded HStack — no
        // child can extend past this frame.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayName: String {
        if let name = auth.account?.displayName, !name.isEmpty { return name }
        return appState.displayName
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    private var memberSinceText: String {
        let label = language == .spanish ? "Miembro desde" : "Member since"
        if let date = auth.account?.createdAt {
            let f = DateFormatter()
            f.locale = Locale(identifier: language == .spanish ? "es" : "en")
            f.dateFormat = "MMM yyyy"
            return "\(label) \(f.string(from: date))"
        }
        return language == .spanish ? "\(label) hoy" : "\(label) today"
    }

    // MARK: - Sign-in / Sign-out (Apple HIG: stay solid black, not styled)

    private var signInPrompt: some View {
        Button {
            HapticEngine.light()
            presentSignIn = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "applelogo")
                Text(language == .spanish ? "Iniciar sesión con Apple" : "Sign in with Apple")
                    .font(.dmSans(14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var signOutButton: some View {
        Button {
            HapticEngine.light()
            Task { await auth.signOut() }
        } label: {
            Text(language == .spanish ? "Cerrar sesión" : "Sign out")
                .font(.dmSans(13, weight: .semibold))
                .foregroundStyle(Color.redPen)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Color.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lightLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stamps grid

    private var stampsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language == .spanish ? "Mis sellos" : "My stamps")
                .font(.caveat(24, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .padding(.trailing, 4)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(appState.stamps) { stamp in
                    StampView(stamp: stamp)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.65))
            .sketchBorder(color: .inkBlue.opacity(0.35), lineWidth: 1, cornerRadius: 10, jitter: 1, seed: 88)

            HStack {
                Spacer()
                Text(language == .spanish ? "COLECCIÓN" : "COLLECTION")
                    .font(.dmSans(11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Color.softGray)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stats grid (real data from AppState)

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language == .spanish ? "Estadísticas" : "Stats")
                .font(.caveat(24, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .padding(.trailing, 4)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                statTile(value: "\(appState.totalPoints)",
                         label: language == .spanish ? "Puntos totales" : "Total points")
                statTile(value: "\(appState.streak.totalCompletions)",
                         label: language == .spanish ? "Juegos completados" : "Games completed")
                statTile(value: "\(appState.streak.currentStreak)",
                         label: language == .spanish ? "Racha actual" : "Current streak")
                statTile(value: "\(earnedStampCount)",
                         label: language == .spanish ? "Sellos ganados" : "Stamps earned")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Caveat digits (4, 7, 9 especially) carry tails that extend past
            // their advance width, so plain `Text` clips them — a 4-digit
            // point total lost its last glyph. InkBoundsLabel measures actual
            // ink, so it can't clip at any value.
            InkBoundsLabel.caveat(value, size: 28, weight: .bold, color: .inkBlue)
                .fixedSize()
            Text(label)
                .font(.dmSans(11))
                .foregroundStyle(Color.softGray)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.6))
        .sketchBorder(color: .lightLine, lineWidth: 1, cornerRadius: 8, jitter: 0.9, seed: UInt64(label.hashValue & 0xFFFF))
    }

    private var earnedStampCount: Int {
        appState.stamps.filter { $0.isEarned }.count
    }

    // MARK: - Streak section

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\u{1F525}").font(.system(size: 22))
                Text(longestStreakText)
                    .font(.caveat(22, weight: .bold))
                    .foregroundStyle(Color.redPen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.trailing, 4)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Tally only renders if the longest streak is non-zero —
            // saves vertical space + an empty row at first launch.
            if appState.streak.longestStreak > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    TallyMarksView(
                        count: appState.streak.longestStreak,
                        color: .redPen
                    )
                    .frame(height: 22)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var longestStreakText: String {
        let n = appState.streak.longestStreak
        if language == .spanish {
            return n == 1 ? "Racha más larga: 1 día" : "Racha más larga: \(n) días"
        }
        return n == 1 ? "Longest streak: 1 day" : "Longest streak: \(n) days"
    }
}

// MARK: - StampSeal (user avatar)

/// Postage-stamp seal used as the user's avatar on Profile. Self-frames
/// at 84×84 so it can never push siblings off-screen.
struct StampSeal: View {
    let initials: String

    var body: some View {
        ZStack {
            SketchCircle(seed: 22, wobbleScale: 1.0)
                .stroke(Color.inkBlue, style: SwiftUI.StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [3, 2]))
            VStack(spacing: 0) {
                Text("SCRIBBLD")
                    .font(.dmSans(7, weight: .bold))
                    .tracking(1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(initials)
                    .font(.caveat(30, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("PLAYER")
                    .font(.dmSans(7, weight: .bold))
                    .tracking(1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .foregroundStyle(Color.inkBlue)
            .padding(.horizontal, 6)
        }
        .frame(width: 84, height: 84)
        .accessibilityHidden(true)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(StoreManager())
        .environmentObject(AuthService())
}
