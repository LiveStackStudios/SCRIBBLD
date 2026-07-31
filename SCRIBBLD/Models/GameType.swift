import SwiftUI

enum GameType: String, CaseIterable, Identifiable, Codable, Hashable {
    case ticTacToe
    case dotsAndBoxes
    case hangman
    case stop
    case sandSnake
    case sketching

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ticTacToe:    return "Tic Tac Toe"
        case .dotsAndBoxes: return "Dots and Boxes"
        case .hangman:      return "Hangman"
        case .stop:         return "Stop"
        case .sandSnake:    return "Sand Snake"
        case .sketching:    return "Sketching"
        }
    }

    var blurb: String {
        switch self {
        case .ticTacToe:    return "Hand sketched X's and O's"
        case .dotsAndBoxes: return "Capture more boxes than your rival"
        case .hangman:      return "Sketched gallows, letter blanks"
        case .stop:         return "Stop sign or icon, hand, and letters"
        case .sandSnake:    return "Burrow through the sand, hunt the grubs"
        case .sketching:    return "Free-draw with brushes and palette"
        }
    }

    var accent: Color {
        switch self {
        case .ticTacToe:    return .inkBlue
        case .dotsAndBoxes: return .inkBlue
        case .hangman:      return .inkBlue
        case .stop:         return .redPen
        case .sandSnake:    return .goldAccent
        case .sketching:    return .inkBlue
        }
    }

    /// Solo-only games can't be challenged to a friend. Sketching is a
    /// drawing surface and Sand Snake is a single-player run.
    var isSoloOnly: Bool {
        self == .sketching || self == .sandSnake
    }
}
