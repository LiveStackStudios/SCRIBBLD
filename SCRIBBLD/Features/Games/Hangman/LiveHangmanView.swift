import SwiftUI

struct LiveHangmanView: View {
    @StateObject private var vm: LiveHangmanViewModel
    @Environment(\.dismiss) private var dismiss

    private let keyboardRows: [[Character]] = [
        Array("QWERTYUIOP"),
        Array("ASDFGHJKL"),
        Array("ZXCVBNM")
    ]

    init(gameId: String, me: AuthAccount) {
        _vm = StateObject(wrappedValue: LiveHangmanViewModel(gameId: gameId, me: me))
    }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView(lineOpacity: 0.18).ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                topBar
                subtitle
                drawingCard
                wrongLettersRow
                statusRow
                BannerAdView(adUnitID: AdConfig.Banner.home)
                Spacer(minLength: 4)
                if vm.amGuesser {
                    keyboard
                } else {
                    pickerBanner
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, 4)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").foregroundStyle(Color.inkBlue) }
            }
        }
        .onAppear { vm.observe() }
        .onDisappear { vm.stop() }
    }

    private var topBar: some View {
        HStack {
            ScribbldWordmark(size: 20)
            Spacer()
            Text("LIVE · Hangman")
                .font(.dmSans(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Color.redPen)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.inkBlue.opacity(0.4)).frame(height: 0.6).offset(y: 8)
        }
        .padding(.vertical, 6)
    }

    private var subtitle: some View {
        Text(vm.amPicker ? "YOU PICKED · WATCHING \(vm.opponentName.uppercased())" : "GUESS THE WORD · BY \(vm.opponentName.uppercased())")
            .font(.dmSans(11, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(Color.softGray)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var drawingCard: some View {
        VStack(spacing: 12) {
            GallowsView(stage: vm.stage)
                .frame(height: 220)
                .overlay(NotebookLines().allowsHitTesting(false))

            // The full word is revealed here at game end. At 34pt a word
            // ending in S/T/Y/F/I loses up to ~7pt of ink without trailing
            // room — the solo HangmanView has these modifiers, this
            // multiplayer twin didn't.
            Text(vm.revealed)
                .font(.caveat(34, weight: .bold))
                .foregroundStyle(vm.winner == vm.me.uid ? Color.inkGreen : Color.inkBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 12)
                .padding(.trailing, 8)
                .fixedSize(horizontal: false, vertical: true)
                .zIndex(1)
                .padding(.vertical, 6)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(Color.inkBlue.opacity(0.18), lineWidth: 0.7))
    }

    private var wrongLettersRow: some View {
        HStack(spacing: 8) {
            ForEach(vm.wrong, id: \.self) { letter in
                ZStack {
                    Text(String(letter))
                        .font(.dmSans(18, weight: .bold))
                        .foregroundStyle(Color.inkBlue)
                    StrikeShape()
                        .stroke(Color.redPen, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .frame(width: 22, height: 22)
                }
                .frame(width: 22, height: 22)
            }
        }
        .frame(minHeight: 28)
    }

    private var statusRow: some View {
        HStack {
            Text("\(guessesLeftLabel): \(vm.guessesLeft)")
            Spacer()
            Text("\(categoryLabel): \(displayedCategory)")
        }
        .font(.dmSans(11, weight: .semibold))
        .tracking(1.5)
        .foregroundStyle(Color.softGray)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var guessesLeftLabel: String {
        switch vm.language {
        case .english:   return "GUESSES LEFT"
        case .spanish:   return "INTENTOS"
        case .bilingual: return "GUESSES LEFT"
        }
    }

    private var categoryLabel: String {
        switch vm.language {
        case .english:   return "CATEGORY"
        case .spanish:   return "CATEGORÍA"
        case .bilingual: return "CATEGORY"
        }
    }

    /// Resolve the persisted rawValue (e.g. "ANIMALS") to a localized
    /// display name. Stays robust to unknown values from older docs.
    private var displayedCategory: String {
        if let cat = HangmanCategory(rawValue: vm.category) {
            return cat.displayName(in: vm.language).uppercased()
        }
        return vm.category.uppercased()
    }

    private var keyboard: some View {
        VStack(spacing: 8) {
            ForEach(keyboardRows.indices, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    if rowIndex == 1 { Spacer(minLength: 14) }
                    ForEach(keyboardRows[rowIndex], id: \.self) { letter in
                        KeyboardKey(letter: letter, state: state(for: letter)) {
                            vm.guess(letter)
                        }
                    }
                    if rowIndex == 1 { Spacer(minLength: 14) }
                }
            }
        }
        .padding(.vertical, 10)
    }

    private var pickerBanner: some View {
        VStack(spacing: 6) {
            Text("\(vm.opponentName) is guessing.")
                .font(.caveat(20, weight: .bold))
                .foregroundStyle(Color.inkBlue)
            Text("Live updates appear above as letters are tried.")
                .font(.dmSans(12))
                .foregroundStyle(Color.softGray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }

    private func state(for letter: Character) -> KeyboardKey.State {
        let l = Character(letter.uppercased())
        if !vm.guessed.contains(l) { return .available }
        if vm.word.contains(l) { return .correct }
        return .wrong
    }
}
