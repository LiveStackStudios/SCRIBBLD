import Foundation
import SwiftUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct LiveGameInvite: Identifiable, Hashable {
    var id: String         // gameId
    var kind: LiveGameKind
    var fromUID: String
    var fromName: String
    var createdAt: Date
}

@MainActor
final class InvitesService: ObservableObject {
    @Published private(set) var incoming: [LiveGameInvite] = []

    #if canImport(FirebaseFirestore)
    private var listener: ListenerRegistration?
    #endif

    func observe(uid: String) {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { return }
        listener?.remove()
        listener = Firestore.firestore()
            .collection("users").document(uid).collection("invites")
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snap, _ in
                let docs = snap?.documents ?? []
                let invites: [LiveGameInvite] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let kindRaw = data["type"] as? String,
                          let kind = LiveGameKind(rawValue: kindRaw) else { return nil }
                    return LiveGameInvite(
                        id: doc.documentID,
                        kind: kind,
                        fromUID: (data["from"] as? String) ?? "",
                        fromName: Self.sanitizedName(data["fromName"] as? String),
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
                Task { @MainActor in
                    if self?.incoming != invites {
                        // Light haptic if new invite arrived while app is open
                        if let count = self?.incoming.count, invites.count > count {
                            HapticEngine.medium()
                        }
                        self?.incoming = invites
                    }
                }
            }
        #endif
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        #endif
        incoming = []
    }

    /// The inviter writes `fromName` themselves, so collapse whitespace and
    /// cap the length before it reaches the UI.
    static func sanitizedName(_ raw: String?) -> String {
        guard let raw else { return "Friend" }
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let capped = String(collapsed.prefix(32))
        return capped.isEmpty ? "Friend" : capped
    }
}
