import Foundation

struct StreakData: Codable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastCompletedDate: Date?
    var freezesAvailable: Int = 1
    var freezeUsedThisWeek: Bool = false
    var totalCompletions: Int = 0

    static let defaultsKey = "scribbld.streak"

    static func load() -> StreakData {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(StreakData.self, from: data) else {
            return StreakData()
        }
        return decoded
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.defaultsKey)
        }
    }

    mutating func recordCompletion(on date: Date = Date()) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: date)
        if let last = lastCompletedDate {
            let lastDay = cal.startOfDay(for: last)
            if lastDay == today { return }
            let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
            if lastDay == yesterday {
                currentStreak += 1
            } else if freezesAvailable > 0,
                      let daysMissed = cal.dateComponents([.day], from: lastDay, to: today).day,
                      daysMissed == 2 {
                freezesAvailable -= 1
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }
        longestStreak = max(longestStreak, currentStreak)
        totalCompletions += 1
        lastCompletedDate = today
        save()
    }
}
