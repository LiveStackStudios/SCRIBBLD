import Foundation
import SwiftUI

/// Live D&B state-mapping VM. Edges + boxes stored as Firestore-friendly
/// dictionary blobs keyed by `"h-{row}-{col}"` / `"v-{row}-{col}"` for
/// edges and `"{row}-{col}"` for boxes; values are owning player UIDs.
@MainActor
final class LiveDotsAndBoxesViewModel: ObservableObject {
    @Published private(set) var size: Int = 5
    @Published private(set) var edges: [DBEdge: String] = [:]   // edge → owner uid
    @Published private(set) var boxes: [DBBox] = []
    @Published private(set) var currentTurn: String = ""
    @Published private(set) var status: LiveGameStatus = .pending
    @Published private(set) var winner: String?
    @Published private(set) var playerNames: [String: String] = [:]
    @Published private(set) var edgeAnimation: [DBEdge: Double] = [:]
    @Published private(set) var boxAnimation: [Int: Double] = [:]
    @Published var pulseScore = false

    let gameId: String
    let me: AuthAccount

    init(gameId: String, me: AuthAccount) {
        self.gameId = gameId
        self.me = me
    }

    /// `state.size` comes off a client-written doc, and the grid loops below
    /// are `0..<(size - 1)` — an unclamped 0 traps and a huge value hangs the
    /// UI thread. Every read of it goes through here.
    static let sizeRange = 2...9
    static func clampedSize(_ raw: Any?, fallback: Int = 5) -> Int {
        guard let n = raw as? Int else { return fallback }
        return min(max(n, sizeRange.lowerBound), sizeRange.upperBound)
    }

    var isMyTurn: Bool { currentTurn == me.uid }
    var isGameOver: Bool { status == .completed || status == .abandoned }
    var myScore: Int { boxes.filter { $0.owner != nil && ownerUID(of: $0) == me.uid }.count }
    var theirScore: Int { boxes.filter { $0.owner != nil && ownerUID(of: $0) != nil && ownerUID(of: $0) != me.uid }.count }
    var opponentName: String { playerNames.first(where: { $0.key != me.uid })?.value ?? "Opponent" }

    /// Tag box owner via the stored uid in `_ownerUID` we set inside `apply`.
    private var ownersByBoxIndex: [Int: String] = [:]
    private func ownerUID(of box: DBBox) -> String? {
        guard let idx = boxes.firstIndex(of: box) else { return nil }
        return ownersByBoxIndex[idx]
    }

    func observe() {
        LiveGameService.shared.observe(gameId: gameId) { [weak self] doc in
            guard let self, let doc else { return }
            self.apply(doc: doc)
        }
    }

    func stop() { LiveGameService.shared.stopObserving() }

    func play(edge: DBEdge) {
        guard !isGameOver, isMyTurn, edges[edge] == nil else {
            HapticEngine.error(); return
        }
        HapticEngine.light()
        Task {
            try? await LiveGameService.shared.applyMove(gameId: gameId) { doc -> [String: Any]? in
                guard doc.currentTurn == self.me.uid else { return nil }
                var edgesMap = (doc.state["edges"] as? [String: String]) ?? [:]
                let key = Self.edgeKey(edge)
                guard edgesMap[key] == nil else { return nil }
                edgesMap[key] = self.me.uid

                // Compute box ownership after this move
                let size = Self.clampedSize(doc.state["size"], fallback: self.size)
                var boxesMap = (doc.state["boxes"] as? [String: String]) ?? [:]
                var claimedAny = false
                for r in 0..<(size - 1) {
                    for c in 0..<(size - 1) {
                        let bKey = "\(r)-\(c)"
                        if boxesMap[bKey] != nil { continue }
                        let sides = [
                            "h-\(r)-\(c)", "h-\(r + 1)-\(c)",
                            "v-\(r)-\(c)", "v-\(r)-\(c + 1)"
                        ]
                        if sides.allSatisfy({ edgesMap[$0] != nil }) {
                            boxesMap[bKey] = self.me.uid
                            claimedAny = true
                        }
                    }
                }

                let totalBoxes = (size - 1) * (size - 1)
                let isComplete = boxesMap.count == totalBoxes
                let nextTurn: String
                if claimedAny && !isComplete {
                    nextTurn = self.me.uid // bonus turn
                } else {
                    nextTurn = doc.players.first(where: { $0 != self.me.uid }) ?? self.me.uid
                }

                var newStatus = doc.status
                var winnerUID: Any = NSNull()
                if isComplete {
                    newStatus = .completed
                    let mineCount = boxesMap.values.filter { $0 == self.me.uid }.count
                    let oppUID = doc.players.first(where: { $0 != self.me.uid })
                    let theirCount = boxesMap.values.filter { $0 == oppUID }.count
                    if mineCount > theirCount { winnerUID = self.me.uid }
                    else if theirCount > mineCount, let opp = oppUID { winnerUID = opp }
                    else { winnerUID = "draw" }
                }

                return [
                    "state": [
                        "size": size,
                        "edges": edgesMap,
                        "boxes": boxesMap
                    ] as [String: Any],
                    "currentTurn": nextTurn,
                    "status": newStatus.rawValue,
                    "winner": winnerUID
                ]
            }
        }
    }

    private func apply(doc: LiveGameDoc) {
        status = doc.status
        currentTurn = doc.currentTurn
        playerNames = doc.playerNames
        winner = doc.winner
        size = Self.clampedSize(doc.state["size"])

        // Edges
        let raw = (doc.state["edges"] as? [String: String]) ?? [:]
        var newEdges: [DBEdge: String] = [:]
        for (key, owner) in raw {
            guard let e = Self.decodeEdge(key) else { continue }
            newEdges[e] = owner
            if edgeAnimation[e] == nil {
                edgeAnimation[e] = 0
                withAnimation(.easeOut(duration: 0.18)) { edgeAnimation[e] = 1 }
            }
        }
        edges = newEdges

        // Boxes
        let bRaw = (doc.state["boxes"] as? [String: String]) ?? [:]
        boxes = (0..<(size - 1)).flatMap { r in
            (0..<(size - 1)).map { c -> DBBox in
                var box = DBBox(row: r, col: c)
                if let owner = bRaw["\(r)-\(c)"] {
                    box.owner = (owner == me.uid) ? .me : .them
                }
                return box
            }
        }
        ownersByBoxIndex = [:]
        for (idx, box) in boxes.enumerated() {
            ownersByBoxIndex[idx] = bRaw["\(box.row)-\(box.col)"]
            if box.owner != nil, boxAnimation[idx] == nil {
                boxAnimation[idx] = 0
                withAnimation(.easeOut(duration: 0.5)) { boxAnimation[idx] = 1 }
            }
        }
    }

    // MARK: - Edge encoding

    static func edgeKey(_ edge: DBEdge) -> String {
        let o = edge.orientation == .horizontal ? "h" : "v"
        return "\(o)-\(edge.row)-\(edge.col)"
    }

    static func decodeEdge(_ key: String) -> DBEdge? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let r = Int(parts[1]), let c = Int(parts[2]) else { return nil }
        let orientation: DBEdge.Orientation = (parts[0] == "h") ? .horizontal : .vertical
        return DBEdge(orientation: orientation, row: r, col: c)
    }

    static func initialState(size: Int = 5) -> [String: Any] {
        ["size": size, "edges": [String: String](), "boxes": [String: String]()]
    }
}
