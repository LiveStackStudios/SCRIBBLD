import Foundation

enum GameOutcome: String, Codable {
    case win, loss, draw
}

struct GameResult: Identifiable, Codable, Hashable {
    var id = UUID()
    var game: GameType
    var outcome: GameOutcome
    var score: Int
    var correctAnswers: Int?
    var totalAnswers: Int?
    var durationSeconds: Int
    var date: Date

    var formattedDuration: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
