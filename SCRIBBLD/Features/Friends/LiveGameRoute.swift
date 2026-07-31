import Foundation

/// Identifiable + Hashable wrapper for SwiftUI's `navigationDestination(item:)`.
struct LiveGameRoute: Identifiable, Hashable {
    var id: String { gameId }
    let kind: LiveGameKind
    let gameId: String
}
