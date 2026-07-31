import SwiftUI

struct Stamp: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var subtitle: String
    var iconSystemName: String
    var tint: StampTint
    var earnedDate: Date?

    var isEarned: Bool { earnedDate != nil }
}

enum StampTint: String, Codable {
    case ink, red

    var color: Color {
        switch self {
        case .ink: return .inkBlue
        case .red: return .redPen
        }
    }
}

extension Stamp {
    static let starter: [Stamp] = [
        Stamp(title: "7 Day",     subtitle: "STREAK",    iconSystemName: "star.fill",        tint: .ink, earnedDate: Date()),
        Stamp(title: "Mindful",   subtitle: "WRITER",    iconSystemName: "pencil.tip",        tint: .ink, earnedDate: Date()),
        Stamp(title: "Creative",  subtitle: "FLOW",      iconSystemName: "scribble.variable", tint: .red, earnedDate: Date()),
        Stamp(title: "Doodle",    subtitle: "CHAMP",     iconSystemName: "trophy.fill",       tint: .ink, earnedDate: Date()),
        Stamp(title: "Ink",       subtitle: "MASTER",    iconSystemName: "drop.fill",         tint: .ink, earnedDate: Date()),
        Stamp(title: "100",       subtitle: "Scribbles", iconSystemName: "number",            tint: .red, earnedDate: nil)
    ]
}
