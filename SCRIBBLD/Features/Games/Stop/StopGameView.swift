import SwiftUI

struct StopGameView: View {
    @StateObject private var vm: StopGameViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: StopCategoryKey?
    @State private var presentPostGame = false

    /// `mode` was previously not a parameter at all: GameDetailView called
    /// `StopGameView(difficulty:)` for every mode, so choosing Pass & Play
    /// silently started a vs-AI game. That is the "pass and play isn't
    /// working" report.
    init(language: GameLanguage = AppLanguage.current,
         mode: GameMode = .vsAI,
         difficulty: AIDifficulty = .medium) {
        let opponents: [AIDifficulty] = (difficulty == .easy) ? [.easy, .easy] : [difficulty, difficulty]
        _vm = StateObject(wrappedValue: StopGameViewModel(
            language: language,
            opponents: opponents,
            passAndPlay: mode == .passAndPlay
        ))
    }

    var body: some View {
        ZStack {
            switch vm.phase {
            case .categorySetup:
                StopCategoryPickerView(vm: vm)
            case .letterReveal:
                StopLetterRevealView(vm: vm)
            case .playing:
                playingScreen
            case .scoring:
                StopScoringView(vm: vm)
            case .roundComplete(let idx):
                roundCompleteScreen(idx: idx)
            case .gameComplete:
                gameCompleteScreen
            }
            if vm.awaitingHandoff {
                handoffOverlay
            }
            if let grace = vm.graceRemaining {
                graceOverlay(grace)
            }
            if vm.stopFlashVisible && vm.graceRemaining == nil {
                Color.redPen.opacity(0.85).ignoresSafeArea()
                    .overlay(
                        Text(vm.stopPhrase)
                            .font(.caveat(40, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            // Every Spanish phrase ends in "!", the biggest
                            // unprotected Caveat in any game screen at 40pt.
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 24)
                            .padding(.trailing, 9)
                            .fixedSize(horizontal: false, vertical: true)
                    )
                    .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").foregroundStyle(Color.inkBlue) }
            }
        }
        .navigationDestination(isPresented: $presentPostGame) {
            PostGameView(result: makeResult(), restart: {
                presentPostGame = false
                vm.reset()
            })
        }
    }

    // MARK: - Playing screen

    /// Someone else called STOP. Input stays live for `graceDuration` more
    /// seconds — without this the round ended instantly and most of the
    /// player's answers were never entered.
    private func graceOverlay(_ remaining: TimeInterval) -> some View {
        let es = vm.game.language == .spanish
        return VStack(spacing: 6) {
            Text(es ? "\(vm.graceCallerName ?? "Alguien") gritó ¡STOP!"
                    : "\(vm.graceCallerName ?? "Someone") called STOP!")
                .font(.dmSans(15, weight: .semibold))
                .foregroundStyle(Color.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HandwrittenLetter(
                letter: "\(max(0, Int(ceil(remaining))))",
                size: 92,
                color: .cream
            )
            Text(es ? "Termina de escribir" : "Finish writing")
                .font(.dmSans(13))
                .foregroundStyle(Color.cream.opacity(0.9))
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
        .background(Color.redPen.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 90)
        .allowsHitTesting(false)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private var playingScreen: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView().ignoresSafeArea().allowsHitTesting(false)
            ScrollView {
                VStack(spacing: 10) {
                    topBar
                    letterStrip
                    grid
                    scoringLegend
                    stopButton
                    playersStrip
                    BannerAdView(adUnitID: AdConfig.Banner.home)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
        }
    }

    private var topBar: some View {
        HStack {
            ScribbldWordmark(size: 20)
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(vm.human.name)
                    .font(.dmSans(11, weight: .semibold))
                    .foregroundStyle(Color.inkBlue)
                    .lineLimit(1)
                Text(vm.game.language == .english ? "Round \(vm.roundNumber) of \(vm.game.totalRounds)" : "Ronda \(vm.roundNumber) de \(vm.game.totalRounds)")
                    .font(.dmSans(10))
                    .foregroundStyle(Color.softGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    private var letterStrip: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                SketchCircle(seed: 41, wobbleScale: 1.2)
                    .stroke(Color.redPen, style: SwiftUI.StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .frame(width: 64, height: 64)
                SketchCircle(seed: 42, wobbleScale: 1.0)
                    .stroke(Color.redPen.opacity(0.45),
                            style: SwiftUI.StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [3, 2]))
                    .frame(width: 54, height: 54)
                HandwrittenLetter(
                    letter: String(vm.displayedLetter),
                    size: 36,
                    color: .redPen,
                    rotation: .degrees(-3)
                )
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.game.language == .english ? "LETTER" : "LETRA")
                    .font(.dmSans(9, weight: .semibold)).tracking(1.5)
                    .foregroundStyle(Color.softGray)
                Text(vm.languageHint)
                    .font(.caveat(16, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(vm.game.language == .english ? "TIME LEFT" : "TIEMPO")
                    .font(.dmSans(9, weight: .semibold)).tracking(1.5)
                    .foregroundStyle(Color.softGray)
                Text(timeString)
                    .font(.caveat(28, weight: .bold))
                    .foregroundStyle(vm.timeRemaining <= 10 ? Color.redPen : Color.inkBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .animation(.easeInOut, value: vm.timeRemaining <= 10)
            }
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(NotebookPaper())
        .overlay(alignment: .top) { Rectangle().fill(Color.gridGray.opacity(0.7)).frame(height: 1).padding(.horizontal, 4) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.gridGray.opacity(0.7)).frame(height: 1).padding(.horizontal, 4) }
    }

    private var grid: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text(vm.game.language == .english ? "Letter" : "Letra")
                    .frame(width: 50, alignment: .center)
                Text(vm.game.language == .english ? "Categories" : "Categorías")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Pts")
                    .frame(width: 50, alignment: .center)
            }
            .font(.dmSans(10, weight: .semibold)).tracking(1.4)
            .foregroundStyle(Color.cream)
            .padding(.vertical, 8)
            .background(Color.inkBlue)

            ForEach(Array(vm.game.categories.enumerated()), id: \.offset) { idx, cat in
                rowFor(category: cat, isFirst: idx == 0)
                if idx < vm.game.categories.count - 1 {
                    Rectangle().fill(Color.inkBlue.opacity(0.5)).frame(height: 1)
                }
            }
        }
        .background(Color(hex: "#FFFEF7"))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.inkBlue, lineWidth: 1.8))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: Color(hex: "#EDE8D8"), radius: 0, x: 2, y: 4)
    }

    @ViewBuilder
    private func rowFor(category: StopCategoryKey, isFirst: Bool) -> some View {
        let isActive = focused == category
        HStack(spacing: 0) {
            ZStack {
                if isFirst {
                    Color(hex: "#FAEEDA")
                    Text(String(vm.displayedLetter))
                        .font(.caveat(24, weight: .bold))
                        .foregroundStyle(Color.redPen)
                } else {
                    Color.clear
                    Text(String(vm.displayedLetter))
                        .font(.caveat(24, weight: .bold))
                        .foregroundStyle(Color.redPen.opacity(0.0001))
                }
            }
            .frame(width: 50)

            Rectangle().fill(Color.inkBlue.opacity(0.7)).frame(width: 2)

            categoryCell(category: category, isActive: isActive)
                .frame(maxWidth: .infinity)

            Rectangle().fill(Color.inkBlue.opacity(0.5)).frame(width: 1)

            Text("—")
                .font(.caveat(20, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .frame(width: 50)
                .frame(maxHeight: .infinity)
                .background(Color(hex: "#E6F1FB"))
        }
        .frame(minHeight: 64)
        .background(isActive ? Color(hex: "#FFF8DC") : Color.clear)
        .overlay(alignment: .leading) {
            if isActive {
                Rectangle().fill(Color.redPen).frame(width: 3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            vm.tapRow(category)
            focused = category
        }
    }

    private func categoryCell(category: StopCategoryKey, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(category.displayName(in: vm.game.language).uppercased())
                .font(.dmSans(9, weight: .semibold)).tracking(1.4)
                .foregroundStyle(Color.softGray)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            TextField("", text: bindingFor(category))
                .focused($focused, equals: category)
                .font(.caveat(20, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .submitLabel(.next)
                .onSubmit { jumpToNext(from: category) }
                // A TextField can't route through InkBoundsLabel, but unlike
                // Text its trailing padding does widen the editing rect — so
                // the character being typed no longer clips on every keystroke.
                .padding(.trailing, 5)
                .overlay(alignment: .leading) {
                    if (vm.currentAnswers[category] ?? "").isEmpty && !isActive {
                        Text("________")
                            .font(.caveat(20, weight: .bold))
                            .foregroundStyle(Color.gridGray)
                            .tracking(2)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func bindingFor(_ cat: StopCategoryKey) -> Binding<String> {
        Binding(
            get: { vm.currentAnswers[cat] ?? "" },
            set: { vm.updateAnswer(cat, $0) }
        )
    }

    private func jumpToNext(from current: StopCategoryKey) {
        let categories = vm.game.categories
        guard let idx = categories.firstIndex(of: current) else { return }
        for offset in 1...categories.count {
            let candidate = categories[(idx + offset) % categories.count]
            if (vm.currentAnswers[candidate] ?? "").isEmpty {
                focused = candidate
                vm.activeCategory = candidate
                return
            }
        }
        focused = nil
    }

    private var scoringLegend: some View {
        HStack(spacing: 8) {
            scoringPiece(value: "100", label: vm.game.language == .english ? "unique" : "único")
            Text("·").foregroundStyle(Color.goldAccent.opacity(0.6))
            scoringPiece(value: "50", label: vm.game.language == .english ? "shared" : "compartido")
            Text("·").foregroundStyle(Color.goldAccent.opacity(0.6))
            scoringPiece(value: "0", label: vm.game.language == .english ? "blank/wrong" : "vacío")
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#FAEEDA"))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.goldAccent, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func scoringPiece(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value).font(.caveat(16, weight: .bold)).foregroundStyle(Color(hex: "#854F0B"))
            Text(label).font(.dmSans(10)).foregroundStyle(Color(hex: "#854F0B"))
        }
    }

    private var stopButton: some View {
        let es = vm.game.language == .spanish
        return Button {
            focused = nil
            if vm.isPassAndPlay {
                vm.finishEntrantTurn()
            } else {
                vm.callStop()
            }
        } label: {
            Text(passAndPlayButtonLabel(es: es))
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .buttonStyle(PencilButtonFilledStyle(color: .redPen, height: 60, seed: 71))
        .rotationEffect(.degrees(-0.8))
    }

    private func passAndPlayButtonLabel(es: Bool) -> String {
        guard vm.isPassAndPlay else { return "¡ STOP !" }
        if vm.isLastEntrant { return es ? "¡ STOP !" : "¡ STOP !" }
        return es ? "PASAR EL TELÉFONO" : "PASS THE PHONE"
    }

    /// Covers the board between turns so the next player can't read what the
    /// previous one wrote.
    private var handoffOverlay: some View {
        let es = vm.game.language == .spanish
        return ZStack {
            Color.inkBlue.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.cream.opacity(0.9))
                Text(es ? "Pásale el teléfono a" : "Pass the phone to")
                    .font(.dmSans(14))
                    .foregroundStyle(Color.cream.opacity(0.85))
                Text(vm.currentEntrant.name)
                    .font(.caveat(40, weight: .bold))
                    .foregroundStyle(Color.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.trailing, 9)
                    .fixedSize(horizontal: false, vertical: true)
                Text(es ? "La letra sigue siendo \(String(vm.displayedLetter))"
                        : "The letter is still \(String(vm.displayedLetter))")
                    .font(.dmSans(13))
                    .foregroundStyle(Color.cream.opacity(0.75))
                Button {
                    vm.beginEntrantTurn()
                } label: {
                    Text(es ? "Estoy listo" : "I'm ready")
                }
                .buttonStyle(PencilButtonFilledStyle(color: .redPen, height: 52, seed: 33))
                .padding(.horizontal, 40)
                .padding(.top, 6)
            }
            .padding(28)
        }
        .transition(.opacity)
    }

    private var playersStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle().fill(Color.gridGray.opacity(0.6))
                .frame(height: 1)
            HStack(spacing: 14) {
                ForEach(vm.game.players) { p in
                    HStack(spacing: 5) {
                        Circle().fill(p.isYou ? Color.redPen : Color.gridGray)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(p.isYou ? Color.redPen.opacity(0.4) : .clear, lineWidth: 4))
                        Text(p.name)
                            .font(.dmSans(11))
                            .foregroundStyle(Color.inkBlue)
                            .lineLimit(1)
                        Text(p.isYou ? "\(vm.filledCount)/\(vm.game.categories.count)" : "…")
                            .font(.caveat(13, weight: .bold))
                            .foregroundStyle(Color.softGray)
                            .lineLimit(1)
                    }
                    .layoutPriority(1)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var timeString: String {
        let s = Int(ceil(vm.timeRemaining))
        return String(format: "0:%02d", s)
    }

    // MARK: - Round complete

    private func roundCompleteScreen(idx: Int) -> some View {
        let round = vm.game.rounds[idx]
        return ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView().ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                Text(vm.game.language == .english ? "Round \(round.roundNumber) results" : "Resultados ronda \(round.roundNumber)")
                    .font(.caveat(28, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.trailing, 7)
                    .fixedSize(horizontal: false, vertical: true)
                    .zIndex(1)
                ForEach(vm.leaderboard) { p in
                    HStack {
                        Text(p.name).font(.caveat(20, weight: .bold)).foregroundStyle(Color.inkBlue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.trailing, 5)
                        Spacer()
                        Text("\(p.totalScore) pts").font(.dmSans(15, weight: .semibold)).foregroundStyle(Color.inkBlue)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.7))
                    .sketchBorder(color: .lightLine, lineWidth: 1, cornerRadius: 8, jitter: 0.6, seed: UInt64(p.id.hashValue & 0xFFFF))
                }
                Button {
                    HapticEngine.medium()
                    vm.startNextRoundFromComplete()
                } label: {
                    HStack(spacing: 6) {
                        Text(vm.game.language == .english ? "Next round" : "Siguiente ronda")
                        Image(systemName: "arrow.right")
                    }
                        .font(.caveat(22, weight: .bold))
                        .foregroundStyle(Color.cream)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.inkBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Game complete

    private var gameCompleteScreen: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView().ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                Text(vm.game.language == .english ? "Final Leaderboard" : "Tabla final")
                    .font(.caveat(32, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                    // Spanish "Tabla final" ends in "l" — 0.163 overshoot.
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.trailing, 8)
                    .fixedSize(horizontal: false, vertical: true)
                    .zIndex(1)
                ForEach(Array(vm.leaderboard.enumerated()), id: \.offset) { i, p in
                    HStack {
                        Text("\(i + 1).").font(.caveat(22, weight: .bold))
                        Text(p.name).font(.caveat(22, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.trailing, 5)
                        Spacer()
                        Text("\(p.totalScore) pts").font(.dmSans(16, weight: .semibold))
                    }
                    .foregroundStyle(i == 0 ? Color.redPen : Color.inkBlue)
                    .padding(12)
                    .background(Color.white.opacity(0.7))
                    .sketchBorder(color: i == 0 ? .redPen : .lightLine, lineWidth: i == 0 ? 1.6 : 1, cornerRadius: 8, jitter: 0.6, seed: UInt64(p.id.hashValue & 0xFFFF))
                }
                Button {
                    appState.record(makeResult())
                    presentPostGame = true
                } label: {
                    HStack(spacing: 6) {
                        Text(vm.game.language == .english ? "Continue" : "Continuar")
                        Image(systemName: "arrow.right")
                    }
                        .font(.caveat(22, weight: .bold))
                        .foregroundStyle(Color.cream)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.inkBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    private func makeResult() -> GameResult {
        let me = vm.human
        let topScore = vm.leaderboard.first?.totalScore ?? 0
        let outcome: GameOutcome
        if me.totalScore == topScore && topScore > 0 { outcome = .win }
        else if me.totalScore == 0 { outcome = .loss }
        else { outcome = .draw }
        return GameResult(
            game: .stop,
            outcome: outcome,
            score: me.totalScore,
            correctAnswers: nil,
            totalAnswers: nil,
            durationSeconds: Int(Date().timeIntervalSince(vm.game.startedAt)),
            date: Date()
        )
    }
}

struct NotebookPaper: View {
    var body: some View {
        Canvas { ctx, size in
            // Horizontal rules every 24pt.
            for y in stride(from: 24.0, to: size.height, by: 24) {
                var p = Path(); p.move(to: CGPoint(x: 4, y: y)); p.addLine(to: CGPoint(x: size.width - 4, y: y))
                ctx.stroke(p, with: .color(Color.gridGray.opacity(0.4)), style: StrokeStyle(lineWidth: 0.6))
            }
            // Red margin at x=40.
            var margin = Path()
            margin.move(to: CGPoint(x: 40, y: 0))
            margin.addLine(to: CGPoint(x: 40, y: size.height))
            ctx.stroke(margin, with: .color(Color.redPen.opacity(0.25)), style: StrokeStyle(lineWidth: 0.6))
        }
    }
}

#Preview {
    NavigationStack {
        StopGameView()
            .environmentObject(AppState())
            .environmentObject(StoreManager())
    }
}
