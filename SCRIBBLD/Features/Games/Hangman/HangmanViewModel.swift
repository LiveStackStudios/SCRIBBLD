import Foundation
import SwiftUI

@MainActor
final class HangmanViewModel: ObservableObject {
    @Published private(set) var category: HangmanCategory
    @Published private(set) var word: String
    @Published private(set) var guessed: Set<Character> = []
    @Published private(set) var wrong: [Character] = []
    @Published private(set) var stage: Int = 0
    @Published private(set) var wonOrLost: GameOutcome?
    @Published private(set) var language: GameLanguage

    let maxStage = 10

    init(language: GameLanguage = AppLanguage.current) {
        self.language = language
        let pick = HangmanCategory.random(in: language)
        self.category = pick.0
        self.word = pick.1
    }

    var revealed: String {
        word.map { guessed.contains($0) ? String($0) : "_" }.joined(separator: " ")
    }

    var guessesLeft: Int { max(0, maxStage - stage) }

    var isFinished: Bool { wonOrLost != nil }

    func guess(_ letter: Character) {
        let upper = Character(letter.uppercased())
        guard !isFinished, !guessed.contains(upper) else { return }
        guessed.insert(upper)
        if word.contains(upper) {
            HapticEngine.soft()
            if word.allSatisfy({ guessed.contains($0) }) {
                wonOrLost = .win
                HapticEngine.success()
            }
        } else {
            wrong.append(upper)
            withAnimation(.easeOut(duration: 0.4)) {
                stage = min(maxStage, stage + 1)
            }
            HapticEngine.error()
            if stage >= maxStage {
                wonOrLost = .loss
            }
        }
    }

    func reset() {
        let pick = HangmanCategory.random(in: language)
        category = pick.0
        word = pick.1
        guessed.removeAll()
        wrong.removeAll()
        stage = 0
        wonOrLost = nil
    }

    /// Reset and switch to a new language at the same time. Used by
    /// the in-game EN/ES toggle so flipping it both updates the
    /// chrome AND picks a fresh word in the new language.
    func reset(language newLanguage: GameLanguage) {
        language = newLanguage
        reset()
    }
}
