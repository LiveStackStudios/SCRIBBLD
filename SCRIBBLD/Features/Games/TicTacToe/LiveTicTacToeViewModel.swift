import Foundation
import SwiftUI

/// Live multiplayer Tic Tac Toe driven by a Firestore game doc.
/// Bridges the LiveGameDoc state blob into the same UI primitives the local
/// `TicTacToeView` already uses (HandDrawnX/HandDrawnO/WinLine/etc.).
@MainActor
final class LiveTicTacToeViewModel: ObservableObject {
    @Published private(set) var board: TTTBoard = TTTBoard()
    @Published private(set) var currentTurn: String = ""        // uid
    @Published private(set) var status: LiveGameStatus = .pending
    @Published private(set) var winner: (player: TTTPlayer, line: [Int])?
    @Published private(set) var winLineProgress: Double = 0
    @Published private(set) var animationProgress: [Int: Double] = [:]
    @Published private(set) var playerNames: [String: String] = [:]
    @Published private(set) var symbolForPlayer: [String: TTTPlayer] = [:]
    @Published var statusMessage: String = "Waiting for opponent…"

    let gameId: String
    let me: AuthAccount

    init(gameId: String, me: AuthAccount) {
        self.gameId = gameId
        self.me = me
    }

    var mySymbol: TTTPlayer? { symbolForPlayer[me.uid] }
    var isMyTurn: Bool { currentTurn == me.uid }
    var isGameOver: Bool { status == .completed || status == .abandoned }

    var opponentName: String {
        playerNames.first(where: { $0.key != me.uid })?.value ?? "Opponent"
    }

    func observe() {
        LiveGameService.shared.observe(gameId: gameId) { [weak self] doc in
            guard let self, let doc else { return }
            self.apply(doc: doc)
        }
    }

    func stop() {
        LiveGameService.shared.stopObserving()
    }

    func tap(at cell: Int) {
        guard !isGameOver, isMyTurn, board.cells[cell] == nil, let symbol = mySymbol else {
            HapticEngine.error()
            return
        }
        HapticEngine.light()
        Task {
            try? await LiveGameService.shared.applyMove(gameId: gameId) { doc -> [String: Any]? in
                // Re-validate against authoritative server state
                guard doc.currentTurn == self.me.uid else { return nil }
                var cells = Self.normalizedCells(doc.state["cells"])
                guard cells.indices.contains(cell), cells[cell].isEmpty else { return nil }
                cells[cell] = symbol == .x ? "x" : "o"

                // Compute winner from new board
                var winState: TTTBoard = TTTBoard()
                for i in 0..<9 {
                    if cells[i] == "x" { winState.place(.x, at: i) }
                    else if cells[i] == "o" { winState.place(.o, at: i) }
                }
                var newStatus = doc.status
                var winnerUID: Any = NSNull()
                if let w = winState.winner() {
                    newStatus = .completed
                    if let winningUID = self.symbolForPlayer.first(where: { $0.value == w.player })?.key {
                        winnerUID = winningUID
                    }
                } else if winState.isFull {
                    newStatus = .completed
                    winnerUID = "draw"
                }

                let nextTurn = doc.players.first(where: { $0 != self.me.uid }) ?? self.me.uid

                let newState: [String: Any] = ["cells": cells]
                return [
                    "state": newState,
                    "currentTurn": newStatus == .completed ? self.me.uid : nextTurn,
                    "status": newStatus.rawValue,
                    "winner": winnerUID
                ]
            }
        }
    }

    private func apply(doc: LiveGameDoc) {
        status = doc.status
        playerNames = doc.playerNames
        currentTurn = doc.currentTurn

        // Assign X to the first uid in players, O to the second.
        if symbolForPlayer.isEmpty, doc.players.count == 2 {
            symbolForPlayer[doc.players[0]] = .x
            symbolForPlayer[doc.players[1]] = .o
        }

        // Pull the cells array from the state blob
        let cells = Self.normalizedCells(doc.state["cells"])
        var newBoard = TTTBoard()
        for i in 0..<9 {
            if cells[i] == "x" { newBoard.place(.x, at: i) }
            else if cells[i] == "o" { newBoard.place(.o, at: i) }
            if !cells[i].isEmpty, animationProgress[i] == nil {
                animationProgress[i] = 0
                withAnimation(.easeOut(duration: 0.28)) {
                    animationProgress[i] = 1
                }
            }
        }
        board = newBoard

        if let win = newBoard.winner() {
            winner = win
            if winLineProgress < 1 {
                withAnimation(.easeOut(duration: 0.45).delay(0.15)) {
                    winLineProgress = 1
                }
            }
        }

        statusMessage = makeStatus(doc: doc)
    }

    /// The shared game doc is client-written, so `state.cells` can be any
    /// length (or absent). Coerce to exactly 9 entries before indexing.
    private static func normalizedCells(_ raw: Any?) -> [String] {
        var cells = (raw as? [String]) ?? []
        if cells.count > 9 { cells = Array(cells.prefix(9)) }
        if cells.count < 9 { cells.append(contentsOf: Array(repeating: "", count: 9 - cells.count)) }
        return cells
    }

    private func makeStatus(doc: LiveGameDoc) -> String {
        switch doc.status {
        case .pending:
            return "Waiting for \(opponentName)…"
        case .abandoned:
            return "Game ended."
        case .completed:
            if doc.winner == "draw" { return "Draw." }
            if doc.winner == me.uid { return "You win!" }
            return "\(opponentName) wins."
        case .active:
            return isMyTurn ? "Your move" : "\(opponentName)'s move"
        }
    }
}
