import SwiftUI

struct ChallengeFriendSheet: View {
    let friend: FriendSummary
    let me: AuthAccount
    let onSent: (LiveGameKind, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: StoreManager
    @State private var sending = false
    @State private var error: String?

    private let options: [LiveGameKind] = [.ticTacToe, .dotsAndBoxes, .hangman, .stop]

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Capsule().fill(Color.lightLine).frame(width: 36, height: 4)
                .padding(.top, 8)

            Text("Challenge \(friend.displayName)")
                .font(.caveat(26, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(options, id: \.self) { kind in
                    optionCard(kind)
                }
            }
            .padding(.horizontal, Spacing.lg)

            if let error {
                Text(error).font(.dmSans(12)).foregroundStyle(Color.redPen)
            }

            Spacer(minLength: 0)
        }
        .background(Color.cream)
    }

    private func optionCard(_ kind: LiveGameKind) -> some View {
        Button {
            HapticEngine.light()
            Task { await sendInvite(kind) }
        } label: {
            VStack(spacing: 6) {
                GameIllustration(game: gameType(kind))
                    .frame(height: 70)
                Text(kind.displayName)
                    .font(.caveat(18, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color.white.opacity(0.75))
            .sketchBorder(color: .inkBlue, lineWidth: 1.4, cornerRadius: 12, jitter: 0.8, seed: UInt64(kind.rawValue.hashValue & 0xFFFF))
        }
        .buttonStyle(.plain)
        .disabled(sending)
    }

    private func gameType(_ k: LiveGameKind) -> GameType {
        switch k {
        case .ticTacToe:    return .ticTacToe
        case .dotsAndBoxes: return .dotsAndBoxes
        case .hangman:      return .hangman
        case .stop:         return .stop
        }
    }

    private func initialState(for kind: LiveGameKind) -> [String: Any] {
        switch kind {
        case .ticTacToe:
            return ["cells": Array(repeating: "", count: 9)]
        case .dotsAndBoxes:
            return LiveDotsAndBoxesViewModel.initialState()
        case .hangman:
            // Pick a word from the offline bank in the inviter's
            // current locale-default language; the joiner picks up
            // the language from the doc and renders chrome to match.
            let language = AppLanguage.current
            let pick = HangmanCategory.random(in: language)
            return LiveHangmanViewModel.initialState(
                word: pick.1,
                pickerUID: me.uid,
                category: pick.0.rawValue,
                language: language
            )
        case .stop:
            return LiveStopViewModel.initialState()
        }
    }

    @MainActor
    private func sendInvite(_ kind: LiveGameKind) async {
        sending = true
        defer { sending = false }
        let id = await LiveGameService.shared.createInvite(
            kind: kind,
            from: me,
            to: friend.id,
            opponentName: friend.displayName,
            initialState: initialState(for: kind),
            maxPlayers: kind.maxPlayers(hostIsPro: store.status.isPro)
        )
        if let id {
            HapticEngine.success()
            onSent(kind, id)
            dismiss()
        } else {
            error = "Couldn't send the invite. Try again."
        }
    }
}
