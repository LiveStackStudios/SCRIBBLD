import SwiftUI

struct FriendsTabView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var friends: FriendsService
    @EnvironmentObject private var invites: InvitesService
    @EnvironmentObject private var store: StoreManager
    @StateObject private var moderation = ModerationService.shared
    @State private var reportTarget: FriendSummary?
    @AppStorage(AppLanguage.storageKey) private var langRaw: String = ""
    private var lang: GameLanguage { GameLanguage.resolve(from: langRaw) }
    @State private var presentSignIn = false
    @State private var searchText: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var challengeTarget: FriendSummary?
    @State private var liveGameRoute: LiveGameRoute?
    /// Tracks the search TextField's focus so we can dismiss the
    /// keyboard from a Cancel button + a tap on the background.
    @FocusState private var searchFocused: Bool
    /// Pending live games the user is a participant in (host of a
    /// share-link lobby OR joiner of a friend invite they haven't
    /// finished). Lets the user re-enter a lobby they backed out of.
    @State private var myPendingGames: [LiveGameDoc] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cream.ignoresSafeArea()
                    // Tap on the empty background dismisses the keyboard.
                    // Bound to Color so it doesn't compete with row taps
                    // inside the ScrollView content layer.
                    .onTapGesture { searchFocused = false }
                GraphPaperView().ignoresSafeArea().allowsHitTesting(false)
                content
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.cream.opacity(0.7), for: .navigationBar)
            // Cancel button + keyboard "Done" appear ONLY while the
            // search field is focused — keeps the chrome quiet the
            // rest of the time.
            .toolbar {
                if searchFocused {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            searchText = ""
                            searchFocused = false
                        }
                        .tint(Color.inkBlue)
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { searchFocused = false }
                            .tint(Color.inkBlue)
                    }
                }
            }
            .sheet(isPresented: $presentSignIn) {
                NavigationStack { SignInView().environmentObject(auth) }
            }
            .sheet(item: $challengeTarget) { friend in
                if let me = auth.account {
                    ChallengeFriendSheet(friend: friend, me: me) { kind, gameId in
                        liveGameRoute = LiveGameRoute(kind: kind, gameId: gameId)
                    }
                    // Sheets don't inherit env objects — the sheet reads
                    // `store` to size a Stop! lobby by entitlement.
                    .environmentObject(store)
                    .presentationDetents([.medium])
                }
            }
            .sheet(item: $reportTarget) { friend in
                ReportPlayerSheet(
                    peerUID: friend.id,
                    displayName: friend.displayName,
                    context: "friends"
                )
            }
            .navigationDestination(item: $liveGameRoute) { route in
                liveGameDestination(route)
            }
        }
        // Subscribe to my pending lobbies whenever the user is signed
        // in. Snapshot listener keeps the section live without manual
        // refresh — newly created lobbies show up immediately, and
        // finished/cancelled games drop out.
        .onAppear {
            if let uid = auth.account?.uid {
                LiveGameService.shared.observeMyPendingGames(uid: uid) { games in
                    myPendingGames = games
                }
            }
        }
        .onDisappear {
            LiveGameService.shared.stopObservingMyPendingGames()
        }
        .onChange(of: auth.account?.uid) { _, newUID in
            if let uid = newUID {
                LiveGameService.shared.observeMyPendingGames(uid: uid) { games in
                    myPendingGames = games
                }
            } else {
                LiveGameService.shared.stopObservingMyPendingGames()
                myPendingGames = []
            }
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

    @ViewBuilder
    private var content: some View {
        if auth.isSignedIn {
            signedInContent
        } else {
            signedOutPrompt
        }
    }

    private var signedOutPrompt: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Text("Friends list lives in the cloud")
                .font(.caveat(28, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.horizontal)
            Text("Sign in with Apple to challenge friends and get a notification when they reply.")
                .font(.dmSans(14))
                .foregroundStyle(Color.softGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                HapticEngine.light()
                presentSignIn = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "applelogo")
                    Text("Sign in with Apple")
                        .font(.dmSans(15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.xl)
            Spacer()
        }
    }

    private var signedInContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                searchField
                if !myPendingGames.isEmpty {
                    section(title: "Your open lobbies") {
                        ForEach(myPendingGames, id: \.id) { game in
                            myPendingGameRow(game)
                        }
                    }
                }
                if !invites.incoming.isEmpty {
                    section(title: "Live invites") {
                        ForEach(invites.incoming) { invite in
                            inviteRow(invite)
                        }
                    }
                }
                if !friends.incomingRequests.isEmpty {
                    section(title: "Requests") {
                        ForEach(friends.incomingRequests) { req in
                            requestRow(req)
                        }
                    }
                }
                if !friends.searchResults.isEmpty {
                    section(title: "Results") {
                        ForEach(friends.searchResults) { person in
                            searchResultRow(person)
                        }
                    }
                }
                section(title: "Your friends") {
                    if friends.friends.isEmpty {
                        Text("Nobody yet — search above to send a request.")
                            .font(.dmSans(13))
                            .foregroundStyle(Color.softGray)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(friends.friends) { friend in
                            friendRow(friend)
                        }
                    }
                }
                BannerAdView(adUnitID: AdConfig.Banner.home)
                    .padding(.top, 8)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        // Dragging the friends list down dismisses the keyboard
        // mid-gesture — the native iOS Messages / Mail behavior.
        .scrollDismissesKeyboard(.interactively)
    }

    /// Re-entry row for a pending game the user is already in. Shows
    /// the game kind, who else is in the lobby, and how many slots
    /// are left. Tap → navigate back into the live view for the
    /// matching game kind.
    private func myPendingGameRow(_ game: LiveGameDoc) -> some View {
        let isHost = game.players.first == auth.account?.uid
        let names = game.players.compactMap { game.playerNames[$0] }
        let slotsLeft = max(0, game.maxPlayers - game.players.count)
        return Button {
            HapticEngine.light()
            liveGameRoute = LiveGameRoute(kind: game.type, gameId: game.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(Color.inkBlue)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(game.type.displayName)
                            .font(.dmSans(13, weight: .semibold))
                            .foregroundStyle(Color.inkBlue)
                        if isHost {
                            Text("HOST")
                                .font(.dmSans(9, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Color.redPen)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.redPen.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text(lobbySubtitle(names: names, slotsLeft: slotsLeft, max: game.maxPlayers))
                        .font(.dmSans(11))
                        .foregroundStyle(Color.softGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.softGray)
            }
            .padding(10)
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    /// "You + Lulu • 3 slots left" — quick summary of who's in the
    /// lobby and how much room there is.
    private func lobbySubtitle(names: [String], slotsLeft: Int, max: Int) -> String {
        let joined = names.count <= 2
            ? names.joined(separator: " + ")
            : "\(names.prefix(2).joined(separator: " + ")) +\(names.count - 2)"
        if max <= 2 {
            return slotsLeft == 0
                ? "Tap to enter the game"
                : "Waiting for opponent"
        }
        return slotsLeft > 0
            ? "\(joined) • \(slotsLeft) slot\(slotsLeft == 1 ? "" : "s") left"
            : "\(joined) • lobby full"
    }

    private func inviteRow(_ invite: LiveGameInvite) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "gamecontroller.fill")
                .foregroundStyle(Color.redPen)
            VStack(alignment: .leading, spacing: 2) {
                // Sender-controlled string — bound it so a pathological
                // display name can't blow out the row.
                Text(invite.fromName)
                    .font(.dmSans(13, weight: .semibold))
                    .foregroundStyle(Color.inkBlue)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("Invited you to \(invite.kind.displayName)")
                    .font(.dmSans(11))
                    .foregroundStyle(Color.softGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
            Button("Play") {
                guard let uid = auth.account?.uid else { return }
                Task {
                    await LiveGameService.shared.acceptInvite(gameId: invite.id, uid: uid)
                    liveGameRoute = LiveGameRoute(kind: invite.kind, gameId: invite.id)
                }
            }
            .font(.dmSans(12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.inkBlue)
            .clipShape(Capsule())
            Button("✕") {
                guard let uid = auth.account?.uid else { return }
                Task { await LiveGameService.shared.declineInvite(gameId: invite.id, uid: uid) }
            }
            .font(.dmSans(12, weight: .semibold))
            .foregroundStyle(Color.redPen)
        }
        .padding(10)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.softGray)
            TextField("Search by name", text: $searchText)
                .font(.dmSans(14))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .focused($searchFocused)
                // Tapping the keyboard "search" button dismisses the
                // keyboard as well — natural exit point.
                .onSubmit { searchFocused = false }
                .onChange(of: searchText) { _, new in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        guard !Task.isCancelled else { return }
                        await friends.search(new.trimmingCharacters(in: .whitespaces))
                    }
                }
            // Inline clear button — visible only when there's text.
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.softGray)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lightLine, lineWidth: 1))
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.dmSans(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Color.softGray)
            VStack(spacing: 8) { content() }
        }
    }

    private func friendRow(_ friend: FriendSummary) -> some View {
        Button {
            HapticEngine.light()
            challengeTarget = friend
        } label: {
            HStack(spacing: 12) {
                Circle().fill(Color.inkBlue.opacity(0.15)).frame(width: 36, height: 36)
                    .overlay(Text(String(friend.displayName.prefix(1)))
                        .font(.caveat(20, weight: .bold))
                        .foregroundStyle(Color.inkBlue))
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(.dmSans(14, weight: .semibold))
                        .foregroundStyle(Color.inkBlue)
                        .lineLimit(1)
                    Text(friend.isOnline ? "Online" : "Tap to challenge")
                        .font(.dmSans(11))
                        .foregroundStyle(Color.softGray)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.softGray)
            }
            .padding(10)
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        // Guideline 1.2 wants reporting reachable where the content is.
        // The row's tap is already "challenge", so moderation lives in a
        // context menu on the same row.
        .contextMenu {
            Button(role: .destructive) {
                reportTarget = friend
            } label: {
                Label(
                    lang == .spanish ? "Reportar o bloquear" : "Report or block",
                    systemImage: "exclamationmark.bubble"
                )
            }
        }
    }

    private func searchResultRow(_ person: FriendSummary) -> some View {
        HStack(spacing: 12) {
            Circle().fill(Color.inkBlue.opacity(0.12)).frame(width: 36, height: 36)
                .overlay(Text(String(person.displayName.prefix(1)))
                    .font(.caveat(20, weight: .bold))
                    .foregroundStyle(Color.inkBlue))
            Text(person.displayName)
                .font(.dmSans(14, weight: .semibold))
                .foregroundStyle(Color.inkBlue)
                .lineLimit(1)
            Spacer()
            Button {
                HapticEngine.light()
                let myName = auth.account?.displayName ?? "Friend"
                Task { await friends.sendRequest(to: person.id, myName: myName) }
            } label: {
                Text("Add")
                    .font(.dmSans(13, weight: .semibold))
                    .foregroundStyle(Color.cream)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.inkBlue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func requestRow(_ req: FriendRequest) -> some View {
        HStack(spacing: 10) {
            Circle().fill(Color.redPen.opacity(0.18)).frame(width: 32, height: 32)
                .overlay(Image(systemName: "person.crop.circle.badge.plus").foregroundStyle(Color.redPen))
            VStack(alignment: .leading, spacing: 2) {
                Text(req.fromName)
                    .font(.dmSans(13, weight: .semibold))
                    .foregroundStyle(Color.inkBlue)
                Text("Wants to play")
                    .font(.dmSans(11))
                    .foregroundStyle(Color.softGray)
            }
            Spacer()
            Button("Accept") {
                let myName = auth.account?.displayName ?? "Friend"
                Task { await friends.accept(req, myName: myName) }
            }
            .font(.dmSans(12, weight: .semibold))
            .foregroundStyle(Color.inkGreen)
            Button("X") {
                Task { await friends.reject(req) }
            }
            .font(.dmSans(12, weight: .semibold))
            .foregroundStyle(Color.redPen)
        }
        .padding(10)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    FriendsTabView()
        .environmentObject(AuthService())
        .environmentObject(FriendsService())
}
