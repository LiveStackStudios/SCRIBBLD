import SwiftUI

/// Payload extracted from a universal link / custom URL scheme. The
/// inviter name and game kind here are URL-supplied hints used for the
/// pre-join blurb only; the authoritative game type comes from the
/// Firestore doc once the joiner commits via `joinOpenInvite`.
struct PendingInvite: Equatable, Hashable {
    let gameId: String
    let kindHint: LiveGameKind?
    let inviterNameHint: String?

    /// Build from a URL such as `scribbld://i/<id>?k=ticTacToe&n=Juan`
    /// or `https://scribbld-prod.firebaseapp.com/i/<id>?k=…&n=…`.
    static func parse(_ url: URL) -> PendingInvite? {
        let parts = url.path.split(separator: "/").map(String.init)
        // Accept either `/i/<id>` or `i/<id>` (the latter when parsed
        // from `scribbld://i/<id>`, where the host is `i`).
        var gameId: String? = nil
        if parts.count >= 2, parts[0] == "i" { gameId = parts[1] }
        else if parts.count == 1 && url.host == "i" { gameId = parts[0] }
        else if let host = url.host, host == "i", parts.isEmpty { gameId = nil }
        // `onOpenURL` fires for our custom scheme from any app on the device,
        // so the id is untrusted input. Firestore auto-ids are 20 alphanumeric
        // characters; anything else can't name a real game and is dropped
        // rather than turned into a document lookup.
        guard let id = gameId,
              id.count == 20,
              id.allSatisfy({ $0.isLetter || $0.isNumber }),
              id.allSatisfy({ $0.isASCII }) else { return nil }

        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = comps?.queryItems ?? []
        let kindRaw = items.first(where: { $0.name == "k" })?.value
        let nameRaw = items.first(where: { $0.name == "n" })?.value
        let kind = kindRaw.flatMap { LiveGameKind(rawValue: $0) }
        // Trim and cap the inviter name — defense against pathological URLs.
        let name = nameRaw
            .map { String($0.prefix(24)) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
        return PendingInvite(gameId: id, kindHint: kind, inviterNameHint: name)
    }
}

struct IncomingInviteView: View {
    let invite: PendingInvite

    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var joining = false
    @State private var error: String?
    @State private var presentSignIn = false
    @State private var liveGameRoute: LiveGameRoute?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cream.ignoresSafeArea()
                GraphPaperView().ignoresSafeArea()
                content
                    .padding(.horizontal, Spacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }.tint(Color.inkBlue)
                }
            }
            .sheet(isPresented: $presentSignIn) {
                NavigationStack { SignInView().environmentObject(auth) }
            }
            .navigationDestination(item: $liveGameRoute) { route in
                liveGameDestination(route)
            }
            .onChange(of: auth.account?.uid) { _, newUID in
                if newUID != nil && presentSignIn {
                    presentSignIn = false
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            heroBlock
            blurbBlock
            if let error {
                Text(error)
                    .font(.dmSans(13))
                    .foregroundStyle(Color.redPen)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            actionButtons
        }
        .padding(.vertical, Spacing.xl)
    }

    private var heroBlock: some View {
        VStack(spacing: 8) {
            if let kind = invite.kindHint {
                GameIllustration(game: gameType(kind))
                    .frame(height: 130)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.white.opacity(0.6))
                    .sketchBorder(color: .inkBlue, lineWidth: 1.4, cornerRadius: Radius.card, seed: 17)
            } else {
                Text("Invite")
                    .font(.caveat(40, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
            }
        }
    }

    private var blurbBlock: some View {
        VStack(spacing: 4) {
            Text(headlineText)
                .font(.caveat(34, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
            Text("Tap Join to start the live game.")
                .font(.dmSans(14))
                .foregroundStyle(Color.softGray)
                .multilineTextAlignment(.center)
        }
    }

    private var headlineText: String {
        let name = invite.inviterNameHint ?? "A friend"
        let game = invite.kindHint?.displayName ?? "a game"
        return "\(name) invited you to play \(game)"
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                HapticEngine.medium()
                onTapJoin()
            } label: {
                if joining {
                    ProgressView().tint(Color.cream)
                } else {
                    Text(auth.isSignedIn ? "Join Game" : "Sign in to Join")
                }
            }
            .buttonStyle(PencilButtonStyle(color: .inkBlue, height: 54, seed: 97))
            .disabled(joining)

            Button {
                HapticEngine.light()
                dismiss()
            } label: {
                Text("Not now")
                    .font(.dmSans(14, weight: .semibold))
                    .foregroundStyle(Color.softGray)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.plain)
        }
    }

    private func onTapJoin() {
        if !auth.isSignedIn {
            presentSignIn = true
            return
        }
        Task { await performJoin() }
    }

    @MainActor
    private func performJoin() async {
        guard let me = auth.account else { return }
        joining = true
        error = nil
        defer { joining = false }
        do {
            let resolvedKind = try await LiveGameService.shared.joinOpenInvite(
                gameId: invite.gameId,
                joiner: me
            )
            let kind = resolvedKind ?? invite.kindHint
            guard let kind else {
                error = "Couldn't determine the game type. Try the link again."
                return
            }
            HapticEngine.success()
            liveGameRoute = LiveGameRoute(kind: kind, gameId: invite.gameId)
        } catch let nsError as NSError {
            error = nsError.localizedDescription
        } catch {
            self.error = "Couldn't join the game. Try again."
        }
    }

    @ViewBuilder
    private func liveGameDestination(_ route: LiveGameRoute) -> some View {
        if let me = auth.account {
            switch route.kind {
            case .ticTacToe:    LiveTicTacToeView(gameId: route.gameId, me: me)
            case .dotsAndBoxes: LiveDotsAndBoxesView(gameId: route.gameId, me: me)
            case .hangman:      LiveHangmanView(gameId: route.gameId, me: me)
            case .stop:         LiveStopView(gameId: route.gameId, me: me)
            }
        }
    }

    private func gameType(_ k: LiveGameKind) -> GameType {
        switch k {
        case .ticTacToe:    return .ticTacToe
        case .dotsAndBoxes: return .dotsAndBoxes
        case .hangman:      return .hangman
        case .stop:         return .stop
        }
    }
}

#Preview {
    IncomingInviteView(invite: PendingInvite(
        gameId: "preview-id",
        kindHint: .ticTacToe,
        inviterNameHint: "Juan"
    ))
    .environmentObject(AuthService())
}
