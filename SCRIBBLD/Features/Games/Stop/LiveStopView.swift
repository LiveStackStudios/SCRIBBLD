import SwiftUI

struct LiveStopView: View {
    @StateObject private var vm: LiveStopViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: StopCategoryKey?

    init(gameId: String, me: AuthAccount) {
        _vm = StateObject(wrappedValue: LiveStopViewModel(gameId: gameId, me: me))
    }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView().ignoresSafeArea().allowsHitTesting(false)
            ScrollView {
                VStack(spacing: 12) {
                    topBar
                    if vm.phase != .lobby {
                        letterStrip
                    }
                    phaseContent
                    BannerAdView(adUnitID: AdConfig.Banner.home)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            // Full-screen 20-second countdown after a player taps STOP.
            // Translucent backdrop so the answer grid stays visible
            // behind the count — players can still see what they've
            // written + add a couple last entries before time's up.
            if vm.phase == .grace {
                graceCountdownOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.phase)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").foregroundStyle(Color.inkBlue) }
            }
        }
        .onAppear { vm.observe() }
        .onDisappear { vm.stop() }
    }

    /// Big screen-filling countdown shown while everyone is in the
    /// 20-second grace window after STOP was called. Number renders
    /// as a giant red pencil glyph (no clipping — uses InkBoundsLabel
    /// via HandwrittenLetter) and the stopper's name is shown so the
    /// table knows who triggered it.
    private var graceCountdownOverlay: some View {
        let seconds = Int(ceil(vm.graceSecondsRemaining))
        let stopperName: String = {
            if let id = vm.stoppedBy, let name = vm.playerNames[id] {
                return name
            }
            return vm.language == .spanish ? "Alguien" : "Someone"
        }()
        return ZStack {
            // Dimmed cream backdrop — lets the answer grid peek
            // through so players can keep glancing at the table.
            Color.cream.opacity(0.85).ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                Text(grabbedStopHeadline(stopper: stopperName))
                    .font(.caveat(28, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.trailing, 4)
                    .fixedSize(horizontal: false, vertical: true)
                    .zIndex(1)
                HandwrittenLetter(
                    letter: "\(seconds)",
                    size: 180,
                    color: .redPen
                )
                .padding(.vertical, 8)
                Text(graceFinishCopy)
                    .font(.dmSans(14, weight: .semibold))
                    .foregroundStyle(Color.softGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .allowsHitTesting(false)  // taps still reach the form behind
    }

    private func grabbedStopHeadline(stopper: String) -> String {
        switch vm.language {
        case .english:   return "\(stopper) hit STOP!"
        case .spanish:   return "¡\(stopper) gritó STOP!"
        case .bilingual: return "\(stopper) hit STOP!"
        }
    }

    private var graceFinishCopy: String {
        switch vm.language {
        case .english:   return "Finish anything you can before time's up."
        case .spanish:   return "Termina lo que puedas antes de que se acabe."
        case .bilingual: return "Finish anything you can / Termina lo que puedas."
        }
    }

    private var topBar: some View {
        HStack {
            ScribbldWordmark(size: 20)
            Spacer()
            Text(topBarLabel)
                .font(.dmSans(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Color.redPen)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 6)
    }

    private var topBarLabel: String {
        if vm.isMultiPlayerLobby {
            return "LIVE · \(vm.players.count) PLAYERS"
        }
        return "LIVE · vs \(vm.opponentName)"
    }

    private var letterStrip: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                SketchCircle(seed: 51, wobbleScale: 1.2)
                    .stroke(Color.redPen, style: SwiftUI.StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .frame(width: 62, height: 62)
                HandwrittenLetter(
                    letter: String(vm.letter),
                    size: 34,
                    color: .redPen,
                    rotation: .degrees(-3)
                )
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(letterLabel).font(.dmSans(9, weight: .semibold)).tracking(1.5).foregroundStyle(Color.softGray)
                Text(letterHint)
                    .font(.caveat(16, weight: .bold)).foregroundStyle(Color.inkBlue)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeLabel).font(.dmSans(9, weight: .semibold)).tracking(1.5).foregroundStyle(Color.softGray)
                Text(String(format: "0:%02d", Int(ceil(vm.secondsRemaining))))
                    .font(.caveat(28, weight: .bold))
                    .foregroundStyle(vm.secondsRemaining <= 10 ? Color.redPen : Color.inkBlue)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(width: 70, alignment: .trailing)
        }
        .padding(12)
        .background(NotebookPaper())
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch vm.phase {
        case .lobby:      lobbyView
        case .playing:    playingGrid
        case .grace:
            // During the 20-second grace window we keep the playing
            // grid live so anyone can still type — but overlay a
            // big screen-filling countdown so it's impossible to
            // miss that STOP was called.
            playingGrid
        case .scoring:    scoringGrid
        case .ended:      endedView
        }
    }

    private var lobbyView: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: 6) {
                Text(lobbyTitle)
                    .font(.caveat(34, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                    .padding(.trailing, 4)
                    .fixedSize(horizontal: true, vertical: true)
                Text(lobbySubtitle)
                    .font(.dmSans(13))
                    .foregroundStyle(Color.softGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 14)

            playerSlots

            if let err = vm.lobbyError {
                Text(err)
                    .font(.dmSans(12))
                    .foregroundStyle(Color.redPen)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if vm.isMultiPlayerLobby && vm.isHost {
                Button {
                    Task { await vm.startLobby() }
                } label: {
                    Text(startGameButtonLabel)
                }
                .buttonStyle(PencilButtonFilledStyle(
                    color: vm.players.count >= 2 ? .redPen : .softGray,
                    height: 56,
                    seed: 89
                ))
                .disabled(vm.players.count < 2)
                .padding(.horizontal, Spacing.md)
            } else if vm.isMultiPlayerLobby {
                Text(waitingForHostText)
                    .font(.dmSans(13, weight: .semibold))
                    .foregroundStyle(Color.softGray)
            }
        }
        .padding(.bottom, 12)
    }

    private var lobbyTitle: String {
        if vm.isMultiPlayerLobby {
            return vm.language == .spanish ? "Sala de espera" : "Lobby"
        }
        return vm.language == .spanish ? "Esperando jugador" : "Waiting for player"
    }

    private var lobbySubtitle: String {
        if vm.isMultiPlayerLobby {
            switch vm.language {
            case .spanish:
                return "Hasta \(vm.maxPlayers) jugadores. El host comienza cuando todos estén listos."
            default:
                return "Up to \(vm.maxPlayers) players. The host starts the game when everyone is in."
            }
        }
        return vm.language == .spanish
            ? "Comparte el enlace con el amigo con quien quieras jugar."
            : "Share the link with the friend you want to play."
    }

    private var startGameButtonLabel: String {
        if vm.players.count >= 2 {
            return vm.language == .spanish ? "Comenzar" : "Start Game"
        }
        return vm.language == .spanish ? "Falta 1 jugador más" : "Need 1 more player"
    }

    private var waitingForHostText: String {
        let host = vm.playerNames[vm.players.first ?? ""] ?? (vm.language == .spanish ? "el host" : "the host")
        return vm.language == .spanish
            ? "Esperando a \(host)…"
            : "Waiting for \(host) to start…"
    }

    private var playerSlots: some View {
        VStack(spacing: 8) {
            ForEach(0..<vm.maxPlayers, id: \.self) { idx in
                playerSlotRow(idx: idx)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    @ViewBuilder
    private func playerSlotRow(idx: Int) -> some View {
        let uid = idx < vm.players.count ? vm.players[idx] : nil
        let name = uid.flatMap { vm.playerNames[$0] }
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(uid == nil ? Color.lightLine.opacity(0.6) : Color.inkBlue.opacity(0.18))
                    .frame(width: 36, height: 36)
                if let initial = name?.prefix(1).uppercased() {
                    Text(initial)
                        .font(.caveat(20, weight: .bold))
                        .foregroundStyle(Color.inkBlue)
                } else {
                    Image(systemName: "person.crop.circle.dashed")
                        .foregroundStyle(Color.softGray)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                if let name {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.dmSans(14, weight: .semibold))
                            .foregroundStyle(Color.inkBlue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if idx == 0 {
                            Text("HOST")
                                .font(.dmSans(9, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Color.redPen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.redPen.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        if uid == vm.me.uid {
                            Text("(you)")
                                .font(.dmSans(11))
                                .foregroundStyle(Color.softGray)
                        }
                    }
                } else {
                    Text("Waiting…")
                        .font(.dmSans(13))
                        .foregroundStyle(Color.softGray)
                        .italic()
                }
            }
            Spacer()
        }
        .padding(10)
        .background(uid == nil ? Color.clear : Color.white.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(uid == nil ? Color.lightLine : Color.clear, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var playingGrid: some View {
        VStack(spacing: 8) {
            ForEach(vm.categoryKeys) { cat in
                LiveAnswerRow(
                    category: cat,
                    language: vm.language,
                    text: Binding(
                        get: { vm.pendingLocal[cat] ?? vm.answers[vm.me.uid]?[cat.rawValue] ?? "" },
                        set: { vm.updateAnswer(cat, $0) }
                    ),
                    isActive: focused == cat
                )
                .focused($focused, equals: cat)
            }
            stopButton
        }
    }

    private var stopButton: some View {
        Button {
            focused = nil
            vm.callStop()
        } label: {
            Text("¡ STOP !")
                .font(.caveat(32, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.redPen)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .rotationEffect(.degrees(-0.8))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private var scoringGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Validate answers")
                .font(.caveat(22, weight: .bold))
                .foregroundStyle(Color.inkBlue)
            Text("Tap ✓ to count an answer, ✗ to reject.")
                .font(.dmSans(12)).foregroundStyle(Color.softGray)
            ForEach(vm.categoryKeys) { cat in
                VStack(alignment: .leading, spacing: 4) {
                    Text(cat.displayName(in: vm.language).uppercased())
                        .font(.dmSans(10, weight: .semibold)).tracking(1.3)
                        .foregroundStyle(Color.inkBlue)
                    ForEach(Array(vm.playerNames.keys.sorted()), id: \.self) { uid in
                        scoringRow(uid: uid, category: cat)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Button {
                vm.applyScores()
            } label: {
                HStack(spacing: 6) {
                    Text("Apply scores")
                    Image(systemName: "arrow.right")
                }
                    .font(.caveat(20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.inkBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    private func scoringRow(uid: String, category: StopCategoryKey) -> some View {
        let text = vm.answers[uid]?[category.rawValue] ?? ""
        let valid = vm.validations[uid]?[category.rawValue] ?? false
        return HStack(spacing: 8) {
            Text(vm.playerNames[uid] ?? uid)
                .font(.dmSans(11, weight: .semibold))
                .foregroundStyle(Color.inkBlue)
                .frame(width: 70, alignment: .leading)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(text.isEmpty ? "—" : text)
                .font(.caveat(18, weight: .bold))
                .foregroundStyle(text.isEmpty ? Color.softGray : Color.inkBlue)
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            Button { vm.setValidation(player: uid, category: category, isValid: true) } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(valid ? Color.inkGreen : Color.lightLine)
            }
            .buttonStyle(.plain).disabled(text.isEmpty)
            Button { vm.setValidation(player: uid, category: category, isValid: false) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(!valid ? Color.redPen : Color.lightLine)
            }
            .buttonStyle(.plain)
        }
    }

    private var endedView: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Headline + leaderboard
            Text(headline)
                .font(.caveat(28, weight: .bold))
                .foregroundStyle(headlineColor)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.7)
                .padding(.trailing, 4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 8) {
                ForEach(Array(vm.scores.sorted(by: { $0.value > $1.value })), id: \.key) { uid, score in
                    HStack {
                        Text(vm.playerNames[uid] ?? uid)
                            .font(.caveat(22, weight: .bold))
                            .foregroundStyle(Color.inkBlue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.trailing, 4)
                        Spacer()
                        Text("\(score) \(vm.language == .spanish ? "pts" : "pts")")
                            .font(.dmSans(15, weight: .semibold))
                            .foregroundStyle(Color.inkBlue)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Per-category answer breakdown — what everyone wrote, and
            // how the points were awarded.
            answersBreakdown
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Stacked category cards showing every player's answer for each
    /// category + the points awarded (10 unique / 5 shared / 0 blank).
    /// Lets players review what their friends actually wrote — Stop!
    /// is half about the words people pick, so this is the most fun
    /// part of the post-round screen.
    private var answersBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(vm.language == .spanish ? "Respuestas" : "Answers")
                .font(.caveat(22, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .padding(.trailing, 4)
                .fixedSize(horizontal: false, vertical: true)
            Text(vm.language == .spanish
                 ? "Verde = único (10 pts) · Dorado = compartido (5) · Gris = vacío"
                 : "Green = unique (10 pts) · Gold = shared (5) · Gray = blank")
                .font(.dmSans(11))
                .foregroundStyle(Color.softGray)
                .padding(.bottom, 4)

            ForEach(vm.categoryKeys, id: \.rawValue) { cat in
                answersCard(for: cat)
            }
        }
    }

    private func answersCard(for cat: StopCategoryKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(cat.displayName(in: vm.language).uppercased())
                .font(.dmSans(10, weight: .semibold)).tracking(1.3)
                .foregroundStyle(Color.softGray)
            ForEach(vm.players, id: \.self) { uid in
                answerRow(uid: uid, category: cat)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func answerRow(uid: String, category cat: StopCategoryKey) -> some View {
        let raw = vm.answers[uid]?[cat.rawValue] ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let normalized = trimmed.lowercased()

        // Recompute the per-cell point award the same way autoScore
        // did — so the breakdown matches the scores at the top.
        let allLowered: [String] = vm.players.compactMap { id in
            let t = (vm.answers[id]?[cat.rawValue] ?? "")
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            return t.isEmpty ? nil : t
        }
        let counts = Dictionary(grouping: allLowered, by: { $0 }).mapValues(\.count)
        let pts: Int = {
            if normalized.isEmpty { return 0 }
            return (counts[normalized] ?? 0) == 1 ? 10 : 5
        }()

        let chipColor: Color = {
            switch pts {
            case 10:  return .inkGreen
            case 5:   return .goldAccent
            default:  return .softGray
            }
        }()

        return HStack(spacing: 8) {
            Text(vm.playerNames[uid] ?? uid)
                .font(.dmSans(12, weight: uid == vm.me.uid ? .bold : .semibold))
                .foregroundStyle(uid == vm.me.uid ? Color.inkBlue : Color.softGray)
                .frame(width: 70, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(trimmed.isEmpty ? "—" : trimmed)
                .font(.caveat(16, weight: .bold))
                .foregroundStyle(trimmed.isEmpty ? Color.softGray : Color.inkBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.trailing, 4)
            Spacer(minLength: 4)
            Text("\(pts)")
                .font(.dmSans(11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(chipColor)
                .clipShape(Capsule())
        }
    }

    private var headline: String {
        if vm.winner == vm.me.uid {
            return vm.language == .spanish ? "¡Maestro de palabras!" : "Word master!"
        }
        if vm.winner == "draw" {
            return vm.language == .spanish ? "Empate" : "Tie game"
        }
        if let w = vm.winner, let name = vm.playerNames[w] {
            return vm.language == .spanish ? "\(name) gana" : "\(name) wins"
        }
        return vm.language == .spanish ? "Fin del juego" : "Game over"
    }

    private var letterLabel: String {
        switch vm.language {
        case .english:   return "LETTER"
        case .spanish:   return "LETRA"
        case .bilingual: return "LETTER"
        }
    }

    private var letterHint: String {
        switch vm.language {
        case .english:   return "Starts with \(vm.letter)!"
        case .spanish:   return "¡Empieza con \(vm.letter)!"
        case .bilingual: return "Starts with \(vm.letter)!"
        }
    }

    private var timeLabel: String {
        switch vm.language {
        case .english:   return "TIME LEFT"
        case .spanish:   return "TIEMPO"
        case .bilingual: return "TIME LEFT"
        }
    }
    private var headlineColor: Color {
        vm.winner == vm.me.uid ? Color.inkGreen : Color.inkBlue
    }
}

private struct LiveAnswerRow: View {
    let category: StopCategoryKey
    let language: GameLanguage
    @Binding var text: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(category.displayName(in: language).uppercased())
                .font(.dmSans(10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Color.softGray)
                .frame(width: 88, alignment: .leading)
                .lineLimit(1).minimumScaleFactor(0.7)
            TextField("", text: $text)
                .font(.caveat(20, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(isActive ? Color(hex: "#FFF8DC") : Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? Color.redPen.opacity(0.6) : Color.lightLine, lineWidth: 1))
    }
}
