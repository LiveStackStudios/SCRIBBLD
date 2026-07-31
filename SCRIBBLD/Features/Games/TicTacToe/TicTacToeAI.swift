import Foundation

enum TTTPlayer: Int, Codable {
    case x = 1, o = -1
    var opposite: TTTPlayer { self == .x ? .o : .x }
}

struct TTTBoard: Equatable {
    private(set) var cells: [TTTPlayer?] = Array(repeating: nil, count: 9)

    static let winLines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6]
    ]

    var emptyIndices: [Int] { cells.indices.filter { cells[$0] == nil } }
    var isFull: Bool { cells.allSatisfy { $0 != nil } }

    func winner() -> (player: TTTPlayer, line: [Int])? {
        for line in Self.winLines {
            if let first = cells[line[0]],
               cells[line[1]] == first,
               cells[line[2]] == first {
                return (first, line)
            }
        }
        return nil
    }

    mutating func place(_ player: TTTPlayer, at index: Int) {
        guard cells[index] == nil else { return }
        cells[index] = player
    }

    mutating func undo(at index: Int) {
        cells[index] = nil
    }
}

enum TicTacToeAI {
    static func bestMove(for board: TTTBoard, as player: TTTPlayer, difficulty: AIDifficulty) -> Int? {
        switch difficulty {
        case .easy:   return easyMove(board)
        case .medium: return mediumMove(board, as: player)
        case .hard:   return minimaxBestMove(board, as: player)
        }
    }

    private static func easyMove(_ board: TTTBoard) -> Int? {
        board.emptyIndices.randomElement()
    }

    private static func mediumMove(_ board: TTTBoard, as player: TTTPlayer) -> Int? {
        if let winning = findWinningMove(board, for: player) { return winning }
        if let block = findWinningMove(board, for: player.opposite) { return block }
        if board.cells[4] == nil { return 4 }
        let corners = [0, 2, 6, 8].filter { board.cells[$0] == nil }
        if let c = corners.randomElement() { return c }
        return easyMove(board)
    }

    private static func findWinningMove(_ board: TTTBoard, for player: TTTPlayer) -> Int? {
        for idx in board.emptyIndices {
            var b = board
            b.place(player, at: idx)
            if b.winner()?.player == player { return idx }
        }
        return nil
    }

    private static func minimaxBestMove(_ board: TTTBoard, as player: TTTPlayer) -> Int? {
        var bestScore = Int.min
        var bestMove: Int?
        for idx in board.emptyIndices {
            var b = board
            b.place(player, at: idx)
            let score = minimax(b, depth: 0, maximizing: false, maximizer: player)
            if score > bestScore {
                bestScore = score
                bestMove = idx
            }
        }
        return bestMove
    }

    private static func minimax(_ board: TTTBoard, depth: Int, maximizing: Bool, maximizer: TTTPlayer) -> Int {
        if let w = board.winner() {
            return w.player == maximizer ? (10 - depth) : (depth - 10)
        }
        if board.isFull { return 0 }
        let player = maximizing ? maximizer : maximizer.opposite
        var best = maximizing ? Int.min : Int.max
        for idx in board.emptyIndices {
            var b = board
            b.place(player, at: idx)
            let s = minimax(b, depth: depth + 1, maximizing: !maximizing, maximizer: maximizer)
            best = maximizing ? max(best, s) : min(best, s)
        }
        return best
    }
}
