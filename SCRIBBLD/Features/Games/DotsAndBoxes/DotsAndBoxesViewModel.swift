import Foundation
import SwiftUI

enum DBPlayer: Int, Codable { case me = 0, them = 1 }

struct DBEdge: Hashable, Codable {
    enum Orientation: String, Codable { case horizontal, vertical }
    var orientation: Orientation
    /// For horizontal: top-left dot row/col. For vertical: top-left dot row/col.
    var row: Int
    var col: Int
}

struct DBBox: Hashable, Codable {
    var row: Int
    var col: Int
    var owner: DBPlayer?
}

@MainActor
final class DotsAndBoxesViewModel: ObservableObject {
    @Published var size: Int
    @Published var edges: [DBEdge: DBPlayer] = [:]
    @Published var boxes: [DBBox] = []
    @Published var current: DBPlayer = .me
    @Published var myScore: Int = 0
    @Published var theirScore: Int = 0
    @Published private(set) var edgeAnimation: [DBEdge: Double] = [:]
    @Published private(set) var boxAnimation: [Int: Double] = [:] // boxes index -> 0…1
    @Published var pulseScore: Bool = false

    let mode: GameMode
    let difficulty: AIDifficulty

    init(size: Int = 5, mode: GameMode = .vsAI, difficulty: AIDifficulty = .medium) {
        self.size = size
        self.mode = mode
        self.difficulty = difficulty
        resetBoxes()
    }

    private func resetBoxes() {
        boxes = (0..<(size - 1)).flatMap { r in
            (0..<(size - 1)).map { c in DBBox(row: r, col: c) }
        }
    }

    var totalBoxes: Int { (size - 1) * (size - 1) }
    var isGameOver: Bool { boxes.allSatisfy { $0.owner != nil } }

    func reset() {
        edges.removeAll()
        edgeAnimation.removeAll()
        boxAnimation.removeAll()
        myScore = 0
        theirScore = 0
        current = .me
        resetBoxes()
    }

    func play(edge: DBEdge) {
        guard !isGameOver, edges[edge] == nil else { return }
        guard mode != .vsAI || current == .me else { return }
        commit(edge: edge, by: current)
        scheduleAIIfNeeded()
    }

    private func commit(edge: DBEdge, by player: DBPlayer) {
        edges[edge] = player
        withAnimation(.easeOut(duration: 0.18)) {
            edgeAnimation[edge] = 1
        }
        HapticEngine.light()

        let claimed = checkBoxesAndClaim(for: player)
        if claimed > 0 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                pulseScore = true
            }
            HapticEngine.medium()
            Task {
                try? await Task.sleep(nanoseconds: 220_000_000)
                pulseScore = false
            }
            // Same player goes again
        } else {
            current = player == .me ? .them : .me
        }

        if isGameOver { HapticEngine.success() }
    }

    private func checkBoxesAndClaim(for player: DBPlayer) -> Int {
        var claimed = 0
        for index in boxes.indices where boxes[index].owner == nil {
            let r = boxes[index].row
            let c = boxes[index].col
            let top = DBEdge(orientation: .horizontal, row: r, col: c)
            let bottom = DBEdge(orientation: .horizontal, row: r + 1, col: c)
            let left = DBEdge(orientation: .vertical, row: r, col: c)
            let right = DBEdge(orientation: .vertical, row: r, col: c + 1)
            if edges[top] != nil, edges[bottom] != nil, edges[left] != nil, edges[right] != nil {
                boxes[index].owner = player
                claimed += 1
                if player == .me { myScore += 1 } else { theirScore += 1 }
                let key = index
                boxAnimation[key] = 0
                withAnimation(.easeOut(duration: 0.5)) {
                    boxAnimation[key] = 1
                }
            }
        }
        return claimed
    }

    private func scheduleAIIfNeeded() {
        guard mode == .vsAI, current == .them, !isGameOver else { return }
        Task { await playAI() }
    }

    private func playAI() async {
        try? await Task.sleep(nanoseconds: 650_000_000)
        let allEdges = unplayedEdges()
        guard !allEdges.isEmpty else { return }

        let move: DBEdge
        switch difficulty {
        case .easy:
            move = allEdges.randomElement()!
        case .medium, .hard:
            // Prefer completing a box if possible; otherwise avoid creating a 3-sided box.
            if let completing = allEdges.first(where: { wouldClose(edge: $0) }) {
                move = completing
            } else {
                let safe = allEdges.filter { !createsThirdSide(edge: $0) }
                move = safe.randomElement() ?? allEdges.randomElement()!
            }
        }
        commit(edge: move, by: .them)
        scheduleAIIfNeeded()
    }

    private func unplayedEdges() -> [DBEdge] {
        var result: [DBEdge] = []
        for r in 0..<size {
            for c in 0..<(size - 1) {
                let e = DBEdge(orientation: .horizontal, row: r, col: c)
                if edges[e] == nil { result.append(e) }
            }
        }
        for r in 0..<(size - 1) {
            for c in 0..<size {
                let e = DBEdge(orientation: .vertical, row: r, col: c)
                if edges[e] == nil { result.append(e) }
            }
        }
        return result
    }

    private func wouldClose(edge: DBEdge) -> Bool {
        var copy = edges
        copy[edge] = .them
        for box in boxes where box.owner == nil {
            let r = box.row, c = box.col
            let sides = [
                DBEdge(orientation: .horizontal, row: r, col: c),
                DBEdge(orientation: .horizontal, row: r + 1, col: c),
                DBEdge(orientation: .vertical, row: r, col: c),
                DBEdge(orientation: .vertical, row: r, col: c + 1)
            ]
            if sides.allSatisfy({ copy[$0] != nil }) { return true }
        }
        return false
    }

    private func createsThirdSide(edge: DBEdge) -> Bool {
        var copy = edges
        copy[edge] = .them
        for box in boxes where box.owner == nil {
            let r = box.row, c = box.col
            let sides = [
                DBEdge(orientation: .horizontal, row: r, col: c),
                DBEdge(orientation: .horizontal, row: r + 1, col: c),
                DBEdge(orientation: .vertical, row: r, col: c),
                DBEdge(orientation: .vertical, row: r, col: c + 1)
            ]
            let drawn = sides.reduce(0) { $0 + (copy[$1] != nil ? 1 : 0) }
            if drawn == 3 { return true }
        }
        return false
    }
}
