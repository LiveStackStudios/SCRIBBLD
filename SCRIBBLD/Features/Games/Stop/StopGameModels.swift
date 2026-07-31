import Foundation

enum GameLanguage: String, Codable, CaseIterable, Identifiable {
    case spanish, english, bilingual
    var id: String { rawValue }
    var label: String {
        switch self {
        case .spanish:   return "Español"
        case .english:   return "English"
        case .bilingual: return "Bilingüe"
        }
    }
}

enum EndReason: String, Codable {
    case stopCalled, timeExpired, allFinished
}

struct StopPlayer: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var isYou: Bool
    var aiDifficulty: AIDifficulty?
    var totalScore: Int = 0

    init(id: UUID = UUID(), name: String, isYou: Bool, aiDifficulty: AIDifficulty? = nil) {
        self.id = id
        self.name = name
        self.isYou = isYou
        self.aiDifficulty = aiDifficulty
    }
}

struct StopRound: Identifiable {
    let id = UUID()
    let roundNumber: Int
    let letter: Character
    var answers: [UUID: [StopCategoryKey: String]] = [:]
    var scores: [UUID: [StopCategoryKey: Int]] = [:]
    var stopCalledBy: UUID?
    var stopBonus: Int = 0
    var endReason: EndReason = .timeExpired
    var endedAt: Date = Date()
}

struct StopGame {
    let id = UUID()
    var players: [StopPlayer]
    var categories: [StopCategoryKey]
    var language: GameLanguage
    var usedLetters: Set<Character> = []
    var roundDuration: TimeInterval
    var totalRounds: Int
    var rounds: [StopRound] = []
    var currentRoundIndex: Int = 0
    var startedAt: Date = Date()
    var finishedAt: Date?

    var currentRound: StopRound? {
        guard currentRoundIndex < rounds.count else { return nil }
        return rounds[currentRoundIndex]
    }

    var human: StopPlayer { players.first(where: { $0.isYou }) ?? players[0] }
}

// MARK: - AI difficulty (reused from GameDetail for parity)

extension AIDifficulty {
    /// Probability the AI fills a given category cell in a round.
    var fillProbability: Double {
        switch self {
        case .easy:   return 0.5
        case .medium: return 0.8
        case .hard:   return 1.0
        }
    }

    /// Lower bound on the player-perceived "round delay" before the AI submits.
    var thinkingDelay: ClosedRange<Double> {
        switch self {
        case .easy:   return 1.5...4.0
        case .medium: return 1.0...3.0
        case .hard:   return 0.5...2.0
        }
    }
}
