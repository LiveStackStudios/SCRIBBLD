import Foundation

struct DailyChallenge: Identifiable, Codable, Hashable {
    var id: String { ISO8601DateFormatter.dayKey.string(from: date) }
    var date: Date
    var game: GameType
    var title: String
    var isCompleted: Bool = false

    static func forToday(date: Date = Date()) -> DailyChallenge {
        let weekday = Calendar.current.component(.weekday, from: date)
        let rotation: [GameType] = [
            .ticTacToe, .dotsAndBoxes, .hangman, .stop, .sketching, .sandSnake, .dotsAndBoxes
        ]
        let game = rotation[(weekday - 1) % rotation.count]
        let title: String
        switch game {
        case .ticTacToe:    title = "Beat the AI in 5 moves"
        case .dotsAndBoxes: title = "Claim 6 boxes in a row"
        case .hangman:      title = "Quick Math"
        case .stop:         title = "Race the timer"
        case .sandSnake:    title = "Catch 10 grubs in one burrow"
        case .sketching:    title = "One sketch, two minutes"
        }
        return DailyChallenge(date: date, game: game, title: title)
    }
}

extension ISO8601DateFormatter {
    static let dayKey: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withYear, .withMonth, .withDay, .withDashSeparatorInDate]
        return f
    }()
}
