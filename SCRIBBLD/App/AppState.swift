import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var streak: StreakData
    @Published var dailyChallenge: DailyChallenge
    @Published var stamps: [Stamp]
    @Published var recentResults: [GameResult] = []
    @Published var displayName: String = "Alex_S"
    @Published var totalPoints: Int = 5_300

    init() {
        self.streak = StreakData.load()
        self.dailyChallenge = DailyChallenge.forToday()
        self.stamps = Stamp.starter
    }

    func record(_ result: GameResult) {
        recentResults.insert(result, at: 0)
        if result.outcome == .win {
            streak.recordCompletion(on: result.date)
        }
        totalPoints += max(result.score, 0)
    }

    func completeDailyChallenge() {
        dailyChallenge.isCompleted = true
        streak.recordCompletion()
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let lang = AppLanguage.current
        switch (hour, lang) {
        case (..<12,  .spanish): return "Buenos días,"
        case (12..<17, .spanish): return "Buenas tardes,"
        case (_,       .spanish): return "Buenas noches,"
        case (..<12,  _): return "Good morning,"
        case (12..<17, _): return "Good afternoon,"
        default:            return "Good evening,"
        }
    }
}
