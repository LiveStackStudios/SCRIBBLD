import Foundation
import SwiftUI

/// Classic hangman over Firestore: one player (`pickerUID`) sets a word,
/// the other (the guesser) plays letters until win or 10 wrong guesses.
@MainActor
final class LiveHangmanViewModel: ObservableObject {
    @Published private(set) var word: String = ""
    @Published private(set) var guessed: Set<Character> = []
    @Published private(set) var wrong: [Character] = []
    @Published private(set) var stage: Int = 0
    @Published private(set) var status: LiveGameStatus = .pending
    @Published private(set) var winner: String?
    @Published private(set) var playerNames: [String: String] = [:]
    @Published private(set) var pickerUID: String = ""
    @Published private(set) var guesserUID: String = ""
    @Published private(set) var category: String = "WORD"
    /// Language the picker chose at creation. Drives the localized
    /// chrome (labels/UI) on both clients.
    @Published private(set) var language: GameLanguage = .english

    let gameId: String
    let me: AuthAccount
    let maxStage = 10

    init(gameId: String, me: AuthAccount) {
        self.gameId = gameId
        self.me = me
    }

    var amPicker: Bool { me.uid == pickerUID }
    var amGuesser: Bool { me.uid == guesserUID }
    var isGameOver: Bool { status == .completed || status == .abandoned }
    var guessesLeft: Int { max(0, maxStage - stage) }
    var opponentName: String { playerNames.first(where: { $0.key != me.uid })?.value ?? "Opponent" }

    /// What the guesser (and picker, after end) sees on the board.
    var revealed: String {
        word.map { c in
            if c == " " { return " " }
            return guessed.contains(c) || isGameOver ? String(c) : "_"
        }.joined(separator: " ")
    }

    func observe() {
        LiveGameService.shared.observe(gameId: gameId) { [weak self] doc in
            guard let self, let doc else { return }
            self.apply(doc: doc)
        }
    }

    func stop() { LiveGameService.shared.stopObserving() }

    /// Only the guesser may submit letters.
    func guess(_ letter: Character) {
        let upper = Character(letter.uppercased())
        guard !isGameOver, amGuesser, !guessed.contains(upper) else {
            HapticEngine.error(); return
        }
        Task {
            try? await LiveGameService.shared.applyMove(gameId: gameId) { doc -> [String: Any]? in
                let word = (doc.state["word"] as? String) ?? ""
                let pickerUID = (doc.state["pickerUID"] as? String) ?? ""
                var guessedArr = (doc.state["guessed"] as? [String]) ?? []
                var wrongArr = (doc.state["wrong"] as? [String]) ?? []
                var stage = (doc.state["stage"] as? Int) ?? 0
                let upperString = String(upper)
                guard !guessedArr.contains(upperString) else { return nil }
                guessedArr.append(upperString)
                let hit = word.contains(upper)
                if hit {
                    HapticEngine.soft()
                } else {
                    wrongArr.append(upperString)
                    stage = min(self.maxStage, stage + 1)
                    HapticEngine.error()
                }

                var newStatus = doc.status
                var winnerUID: Any = NSNull()
                let allRevealed = word.allSatisfy { c in c == " " || guessedArr.contains(String(c)) }
                if allRevealed {
                    newStatus = .completed
                    winnerUID = self.me.uid
                    HapticEngine.success()
                } else if stage >= self.maxStage {
                    newStatus = .completed
                    winnerUID = pickerUID
                }

                let newState: [String: Any] = [
                    "word": word,
                    "pickerUID": pickerUID,
                    "category": (doc.state["category"] as? String) ?? "WORD",
                    "guessed": guessedArr,
                    "wrong": wrongArr,
                    "stage": stage
                ]
                return [
                    "state": newState,
                    "currentTurn": self.me.uid,  // guesser keeps turn until game ends
                    "status": newStatus.rawValue,
                    "winner": winnerUID
                ]
            }
        }
    }

    private func apply(doc: LiveGameDoc) {
        status = doc.status
        playerNames = doc.playerNames
        winner = doc.winner
        pickerUID = (doc.state["pickerUID"] as? String) ?? ""
        word = (doc.state["word"] as? String) ?? ""
        category = (doc.state["category"] as? String) ?? "WORD"
        guesserUID = doc.players.first(where: { $0 != pickerUID }) ?? ""
        guessed = Set(((doc.state["guessed"] as? [String]) ?? []).compactMap { $0.first })
        wrong = ((doc.state["wrong"] as? [String]) ?? []).compactMap { $0.first }
        stage = (doc.state["stage"] as? Int) ?? 0
        if let langRaw = doc.state["language"] as? String,
           let lang = GameLanguage(rawValue: langRaw) {
            language = lang
        }
    }

    /// Builds the initial state blob the inviter writes when creating the game.
    static func initialState(
        word: String,
        pickerUID: String,
        category: String = "WORD",
        language: GameLanguage = AppLanguage.current
    ) -> [String: Any] {
        [
            "word": word.uppercased(),
            "pickerUID": pickerUID,
            "category": category,
            "language": language.rawValue,
            "guessed": [String](),
            "wrong": [String](),
            "stage": 0
        ]
    }
}
