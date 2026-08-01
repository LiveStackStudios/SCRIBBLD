import SwiftUI

enum GameMode: String, CaseIterable, Identifiable, Hashable {
    case vsAI = "vs AI"
    case passAndPlay = "Pass & Play"
    case inviteFriend = "Invite Friend"
    var id: String { rawValue }
}

enum AIDifficulty: String, CaseIterable, Identifiable, Hashable, Codable {
    case easy = "Easy", medium = "Medium", hard = "Hard"
    var id: String { rawValue }
}

struct GameDetailView: View {
    let game: GameType
    @State private var mode: GameMode = .vsAI
    @State private var difficulty: AIDifficulty = .medium
    @State private var startGame = false

    // Invite Friend flow state
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: StoreManager
    @State private var inviteWorking = false
    @State private var inviteError: String?
    @State private var presentSignIn = false
    @State private var shareTarget: InviteShareTarget?
    @State private var pendingGameId: String?
    @State private var pendingKind: LiveGameKind?
    @State private var liveGameRoute: LiveGameRoute?
    @State private var resumeInviteAfterSignIn = false

    @AppStorage(AppLanguage.storageKey) private var langRaw: String = ""
    private var lang: GameLanguage { GameLanguage.resolve(from: langRaw) }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView().ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    hero
                    description
                    modePicker
                    if mode == .vsAI {
                        difficultyPicker
                    }
                    statsGrid
                    startButton
                    if let inviteError {
                        Text(inviteError)
                            .font(.dmSans(12))
                            .foregroundStyle(Color.redPen)
                            .multilineTextAlignment(.center)
                    }
                    howToPlay
                    BannerAdView(adUnitID: AdConfig.Banner.home)
                        .padding(.top, 4)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
            }
        }
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $startGame) {
            destination
        }
        .navigationDestination(item: $liveGameRoute) { route in
            liveGameDestination(route)
        }
        .sheet(isPresented: $presentSignIn, onDismiss: {
            if resumeInviteAfterSignIn, auth.isSignedIn {
                resumeInviteAfterSignIn = false
                beginInviteFlow()
            } else {
                resumeInviteAfterSignIn = false
            }
        }) {
            NavigationStack { SignInView().environmentObject(auth) }
        }
        .sheet(item: $shareTarget) { target in
            InviteShareSheet(
                url: target.url,
                message: target.message,
                onCompletion: { completed in
                    handleShareCompletion(completed)
                }
            )
            .ignoresSafeArea()
        }
    }

    @ViewBuilder private var destination: some View {
        switch game {
        case .ticTacToe:    TicTacToeView(mode: mode, difficulty: difficulty)
        case .dotsAndBoxes: DotsAndBoxesView(mode: mode, difficulty: difficulty)
        case .hangman:      HangmanView()
        case .stop:         StopGameView(mode: mode, difficulty: difficulty)
        case .sandSnake:    SandSnakeView()
        case .sketching:    SketchingView()
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            GameIllustration(game: game)
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.white.opacity(0.55))
                .sketchBorder(color: .inkBlue, lineWidth: 1.4, cornerRadius: Radius.card, seed: 11)
            Text(game.title)
                .font(.caveat(32, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.trailing, 6)
                .fixedSize(horizontal: false, vertical: true)
                .zIndex(1)
        }
    }

    private var description: some View {
        Text(longBlurb)
            .font(.dmSans(14))
            .foregroundStyle(Color.inkBlue.opacity(0.85))
            .multilineTextAlignment(.center)
    }

    private var longBlurb: String {
        switch (game, lang) {
        case (.ticTacToe, .spanish):    return "X's y O's dibujados a mano. Tres en raya y ganas."
        case (.dotsAndBoxes, .spanish): return "Toca para trazar líneas. Captura más cajas que tu rival."
        case (.hangman, .spanish):      return "Adivina la palabra antes de que el muñequito quede colgado."
        case (.stop, .spanish):         return "Vence el tiempo. Llena cada categoría antes del bell."
        case (.sandSnake, .spanish):    return "Excava bajo la arena. Caza larvas y no cruces tu propio rastro."
        case (.sketching, .spanish):    return "Dibuja libremente con texturas, pinceles y una paleta."
        case (.ticTacToe, _):           return "Hand-sketched X's and O's. Beat the AI three in a row."
        case (.dotsAndBoxes, _):        return "Tap to draw lines. Capture more boxes than your rival."
        case (.hangman, _):             return "Guess the word before the stick figure runs out of luck."
        case (.stop, _):                return "Beat the timer. Fill every category before the bell."
        case (.sandSnake, _):           return "Burrow under the sand. Hunt grubs and never cross your own trail."
        case (.sketching, _):           return "Free-draw with paper textures, brushes, and a palette."
        }
    }

    private var modePicker: some View {
        SegmentedSketchPicker(selection: $mode, options: GameMode.allCases)
    }

    private var difficultyPicker: some View {
        SegmentedSketchPicker(selection: $difficulty, options: AIDifficulty.allCases)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatCard(label: "Played", value: "12")
            StatCard(label: "Won", value: "8")
            StatCard(label: "Win Rate", value: "66%")
            StatCard(label: "Best Streak", value: "5")
        }
    }

    private var startButton: some View {
        Button {
            HapticEngine.medium()
            onTapStart()
        } label: {
            if inviteWorking {
                ProgressView().tint(Color.cream)
            } else {
                Text(startButtonLabel)
            }
        }
        .buttonStyle(PencilButtonStyle(
            color: .inkBlue,
            height: 54,
            seed: UInt64(game.rawValue.hashValue & 0xFFFF) &+ UInt64(mode.rawValue.hashValue & 0xFF)
        ))
        .disabled(inviteWorking)
    }

    private var startButtonLabel: String {
        switch (mode, lang) {
        case (.inviteFriend, .spanish):       return "Enviar invitación"
        case (.vsAI, .spanish), (.passAndPlay, .spanish): return "Comenzar"
        case (.inviteFriend, _):              return "Send Invite"
        case (.vsAI, _), (.passAndPlay, _):   return "Start Game"
        }
    }

    private func onTapStart() {
        inviteError = nil
        switch mode {
        case .vsAI, .passAndPlay:
            startGame = true
        case .inviteFriend:
            beginInviteFlow()
        }
    }

    private func beginInviteFlow() {
        guard let kind = LiveGameKind.from(gameType: game) else {
            // GameDetailView isn't presented for sketching, but stay safe.
            inviteError = "This game can't be played with a friend yet."
            return
        }
        guard let me = auth.account else {
            resumeInviteAfterSignIn = true
            presentSignIn = true
            return
        }
        Task { await createAndShare(kind: kind, me: me) }
    }

    @MainActor
    private func createAndShare(kind: LiveGameKind, me: AuthAccount) async {
        inviteWorking = true
        inviteError = nil
        defer { inviteWorking = false }

        let initial = LiveGameKind.openInviteInitialState(kind: kind, inviter: me)
        guard let gameId = await LiveGameService.shared.createOpenInvite(
            kind: kind, from: me, initialState: initial,
            maxPlayers: kind.maxPlayers(hostIsPro: store.premiumUnlocked)
        ) else {
            inviteError = "Couldn't create the invite. Check your connection and try again."
            return
        }

        pendingGameId = gameId
        pendingKind = kind
        let url = InviteLink.url(gameId: gameId, kind: kind, inviterName: me.displayName)
        let message = "\(me.displayName) wants to play \(kind.displayName) with you on SCRIBBLD. Tap to join: \(url.absoluteString)"
        shareTarget = InviteShareTarget(url: url, message: message)
    }

    private func handleShareCompletion(_ completed: Bool) {
        guard let gameId = pendingGameId, let kind = pendingKind else {
            shareTarget = nil
            return
        }
        shareTarget = nil
        if completed {
            HapticEngine.success()
            liveGameRoute = LiveGameRoute(kind: kind, gameId: gameId)
        } else {
            // Per the design spec: abandon-on-dismiss. The Firestore rule
            // only lets us delete while still pending + solo, so this is
            // safe even if the opponent somehow already joined (rare).
            if let me = auth.account {
                Task { await LiveGameService.shared.cancelOpenInvite(gameId: gameId, uid: me.uid) }
            }
        }
        pendingGameId = nil
        pendingKind = nil
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

    private var howToPlay: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(rules, id: \.self) { rule in
                    HStack(alignment: .top, spacing: 8) {
                        Text("·").font(.caveat(20, weight: .bold))
                        Text(rule).font(.dmSans(14))
                    }
                    .foregroundStyle(Color.inkBlue.opacity(0.85))
                }
            }
            .padding(.top, 8)
        } label: {
            Text(lang == .spanish ? "Cómo jugar" : "How to Play")
                .font(.caveat(20, weight: .bold))
                .foregroundStyle(Color.inkBlue)
        }
        .padding(12)
        .background(Color.white.opacity(0.55))
        .sketchBorder(color: .lightLine, lineWidth: 1.2, cornerRadius: 10, seed: 23)
    }

    private var rules: [String] {
        switch (game, lang) {
        case (.ticTacToe, .spanish):
            return ["Toca una casilla para marcar.", "Logra tres en línea, columna o diagonal.", "Deshaz cualquier jugada en tu turno."]
        case (.dotsAndBoxes, .spanish):
            return ["Toca entre dos puntos para trazar una línea.", "Cierra el cuarto lado para reclamar la caja.", "Cada caja ganada te da otro turno."]
        case (.hangman, .spanish):
            return ["Elige letras del teclado.", "Las letras incorrectas agregan partes del muñequito.", "Resuelve la palabra antes de completar la figura."]
        case (.stop, .spanish):
            return ["Llena una respuesta por categoría.", "Presiona STOP cuando termines.", "Las respuestas únicas valen más."]
        case (.sandSnake, .spanish):
            return ["Desliza para girar bajo la arena.", "Cada larva te alarga y acelera.", "Chocar con el borde o contigo mismo termina la partida."]
        case (.sketching, .spanish):
            return ["Elige un pincel y un color.", "Pellizca para hacer zoom, dos dedos para mover.", "Guarda tu página cuando estés listo."]
        case (.ticTacToe, _):
            return ["Tap a cell to place your mark.", "Get three in a row, column, or diagonal.", "Undo any move during your turn."]
        case (.dotsAndBoxes, _):
            return ["Tap between two dots to draw a line.", "Close the fourth side of a box to claim it.", "Each box earned gives you another turn."]
        case (.hangman, _):
            return ["Pick letters from the keyboard.", "Wrong letters add a body part.", "Solve it before the figure is complete."]
        case (.stop, _):
            return ["Fill one answer per category.", "Press STOP when you're done.", "Unique answers score more."]
        case (.sandSnake, _):
            return ["Swipe to steer while you burrow.", "Every grub makes you longer and faster.", "Hitting the edge or your own trail ends the run."]
        case (.sketching, _):
            return ["Pick a brush and a color.", "Pinch to zoom, two fingers to pan.", "Save your page when you're happy."]
        }
    }
}

struct SegmentedSketchPicker<Value: Hashable & Identifiable & CustomStringConvertible>: View where Value.ID: Hashable {
    @Binding var selection: Value
    let options: [Value]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { opt in
                let selected = opt == selection
                let optSeed = UInt64(String(describing: opt).hashValue & 0xFFFF)
                Text(String(describing: opt))
                    .font(.dmSans(13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.cream : Color.inkBlue)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        Group {
                            if selected {
                                // Colored-pencil hatched fill so the
                                // selected option reads as "actually
                                // colored in" with a darker shade +
                                // diagonal pencil strokes peeking
                                // past the wobbly outline.
                                PencilFilledSurface(
                                    color: .inkBlue,
                                    cornerRadius: 18,
                                    seed: optSeed
                                )
                            } else {
                                Color.white.opacity(0.55)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                        }
                    )
                    // Sketch border ONLY on unselected pills — the
                    // selected pill's PencilFilledSurface draws its
                    // own outline already.
                    .overlay(
                        Group {
                            if !selected {
                                SketchBorderShape(cornerRadius: 18, jitter: 1.0, seed: optSeed)
                                    .stroke(Color.inkBlue, lineWidth: 1.2)
                            }
                        }
                    )
                    .onTapGesture {
                        HapticEngine.light()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selection = opt
                        }
                    }
            }
        }
    }
}

extension GameMode: CustomStringConvertible {
    var description: String {
        switch (self, AppLanguage.current) {
        case (.vsAI, .spanish):         return "vs IA"
        case (.passAndPlay, .spanish):  return "Por turnos"
        case (.inviteFriend, .spanish): return "Invitar"
        case (.vsAI, _):                return "vs AI"
        case (.passAndPlay, _):         return "Pass & Play"
        case (.inviteFriend, _):        return "Invite Friend"
        }
    }
}
extension AIDifficulty: CustomStringConvertible {
    var description: String {
        switch (self, AppLanguage.current) {
        case (.easy, .spanish):    return "Fácil"
        case (.medium, .spanish):  return "Medio"
        case (.hard, .spanish):    return "Difícil"
        case (.easy, _):           return "Easy"
        case (.medium, _):         return "Medium"
        case (.hard, _):           return "Hard"
        }
    }
}

struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.caveat(26, weight: .bold))
                .foregroundStyle(Color.inkBlue)
            Text(label)
                .font(.dmSans(11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color.softGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.55))
        .sketchBorder(color: .lightLine, lineWidth: 1, cornerRadius: 10, jitter: 0.8, seed: UInt64(label.hashValue & 0xFFFF))
    }
}

#Preview {
    NavigationStack {
        GameDetailView(game: .ticTacToe)
    }
    .environmentObject(AppState())
    .environmentObject(StoreManager())
}
