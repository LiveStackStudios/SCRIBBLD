import Foundation
import SwiftUI

@MainActor
final class TicTacToeViewModel: ObservableObject {
    @Published private(set) var board = TTTBoard()
    @Published private(set) var current: TTTPlayer = .x
    @Published private(set) var winner: (player: TTTPlayer, line: [Int])?
    @Published private(set) var isDraw = false
    @Published private(set) var moveHistory: [Int] = []
    @Published private(set) var animationProgress: [Int: Double] = [:]
    @Published private(set) var winLineProgress: Double = 0

    @Published var p1Score = 0
    @Published var p2Score = 0

    let mode: GameMode
    let difficulty: AIDifficulty
    let humanPlayer: TTTPlayer = .x

    init(mode: GameMode, difficulty: AIDifficulty) {
        self.mode = mode
        self.difficulty = difficulty
    }

    var isGameOver: Bool { winner != nil || isDraw }

    var statusText: String {
        if let w = winner { return w.player == .x ? "PLAYER 1 (X) WINS!" : "PLAYER 2 (O) WINS!" }
        if isDraw { return "DRAW" }
        return current == .x ? "PLAYER 1 (X) TURN" : (mode == .vsAI ? "AI THINKING…" : "PLAYER 2 (O) TURN")
    }

    func handleTap(at index: Int) {
        guard !isGameOver, board.cells[index] == nil else { return }
        guard mode != .vsAI || current == humanPlayer else { return }
        place(at: index)
        if !isGameOver, mode == .vsAI, current != humanPlayer {
            Task { await playAI() }
        }
    }

    func undo() {
        guard let last = moveHistory.popLast() else { return }
        board.undo(at: last)
        animationProgress[last] = 0
        current = current.opposite
        winner = nil
        isDraw = false
        winLineProgress = 0
        // If AI just moved before undo, also undo human's previous move.
        if mode == .vsAI, let prev = moveHistory.popLast() {
            board.undo(at: prev)
            animationProgress[prev] = 0
            current = current.opposite
        }
    }

    func reset() {
        board = TTTBoard()
        current = .x
        winner = nil
        isDraw = false
        moveHistory.removeAll()
        animationProgress.removeAll()
        winLineProgress = 0
    }

    private func place(at index: Int) {
        board.place(current, at: index)
        moveHistory.append(index)
        animationProgress[index] = 0
        withAnimation(.easeOut(duration: 0.28)) {
            animationProgress[index] = 1
        }
        HapticEngine.light()
        if let w = board.winner() {
            winner = w
            if w.player == .x { p1Score += 1 } else { p2Score += 1 }
            HapticEngine.success()
            withAnimation(.easeOut(duration: 0.45).delay(0.2)) {
                winLineProgress = 1
            }
        } else if board.isFull {
            isDraw = true
            HapticEngine.warning()
        } else {
            current.toggle()
        }
    }

    private func playAI() async {
        try? await Task.sleep(nanoseconds: 600_000_000)
        guard let move = TicTacToeAI.bestMove(for: board, as: current, difficulty: difficulty) else { return }
        place(at: move)
    }
}

private extension TTTPlayer {
    mutating func toggle() { self = self.opposite }
}
