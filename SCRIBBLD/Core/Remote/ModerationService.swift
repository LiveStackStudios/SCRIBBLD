import Foundation
import SwiftUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

/// Why a player was reported. Kept short and fixed so reports are groupable
/// server-side rather than a pile of free text.
enum ReportReason: String, CaseIterable, Identifiable {
    case offensiveName
    case offensiveContent
    case harassment
    case cheating
    case other

    var id: String { rawValue }

    func title(in language: GameLanguage) -> String {
        let es = language == .spanish
        switch self {
        case .offensiveName:    return es ? "Nombre ofensivo" : "Offensive name"
        case .offensiveContent: return es ? "Contenido ofensivo en el juego" : "Offensive in-game content"
        case .harassment:       return es ? "Acoso o abuso" : "Harassment or abuse"
        case .cheating:         return es ? "Trampas" : "Cheating"
        case .other:            return es ? "Otro" : "Something else"
        }
    }
}

/// Blocking, reporting, and account deletion.
///
/// These exist because the App Store requires them, but they're written to be
/// genuinely effective rather than box-ticking: blocks are enforced in
/// `firestore.rules` (a modified client can't route around them), and
/// deletion runs server-side because a client is correctly forbidden from
/// touching the copies of a friendship that live on other people's documents.
@MainActor
final class ModerationService: ObservableObject {
    static let shared = ModerationService()

    @Published private(set) var blockedUIDs: Set<String> = []

    #if canImport(FirebaseFirestore)
    private var listener: ListenerRegistration?
    #endif

    // MARK: - Blocking

    func observeBlocks(uid: String) {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { return }
        listener?.remove()
        listener = Firestore.firestore()
            .collection("users").document(uid).collection("blocked")
            .addSnapshotListener { [weak self] snap, _ in
                let ids = Set((snap?.documents ?? []).map(\.documentID))
                Task { @MainActor in self?.blockedUIDs = ids }
            }
        #endif
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        listener?.remove(); listener = nil
        #endif
        blockedUIDs = []
    }

    func isBlocked(_ uid: String) -> Bool { blockedUIDs.contains(uid) }

    /// Block a player. Also drops the existing friendship and any pending
    /// invite from them, so blocking takes effect on screen immediately
    /// rather than only preventing future contact.
    func block(_ peerUID: String, displayName: String) async {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        guard RemoteBootstrap.isFirebaseConfigured,
              let me = Auth.auth().currentUser?.uid, peerUID != me else { return }
        let db = Firestore.firestore()
        let mine = db.collection("users").document(me)
        try? await mine.collection("blocked").document(peerUID).setData([
            "displayName": String(displayName.prefix(32)),
            "blockedAt": Timestamp(date: Date())
        ])
        // Clean up existing contact surfaces.
        try? await mine.collection("friends").document(peerUID).delete()
        try? await mine.collection("friendRequests").document(peerUID).delete()
        let invites = try? await mine.collection("invites")
            .whereField("from", isEqualTo: peerUID).getDocuments()
        for doc in invites?.documents ?? [] { try? await doc.reference.delete() }
        HapticEngine.medium()
        #endif
    }

    func unblock(_ peerUID: String) async {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        guard RemoteBootstrap.isFirebaseConfigured,
              let me = Auth.auth().currentUser?.uid else { return }
        try? await Firestore.firestore()
            .collection("users").document(me)
            .collection("blocked").document(peerUID).delete()
        #endif
    }

    // MARK: - Reporting

    /// File an abuse report. Clients can create these but never read them
    /// back, so nobody can discover who has been reported.
    func report(
        peerUID: String,
        displayName: String,
        reason: ReportReason,
        note: String,
        context: String
    ) async -> Bool {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        guard RemoteBootstrap.isFirebaseConfigured,
              let me = Auth.auth().currentUser?.uid, peerUID != me else { return false }
        do {
            try await Firestore.firestore().collection("reports").addDocument(data: [
                "reporterUID": me,
                "reportedUID": peerUID,
                "reportedName": String(displayName.prefix(64)),
                "reason": reason.rawValue,
                "note": String(note.prefix(500)),
                "context": context,
                "createdAt": Timestamp(date: Date())
            ])
            return true
        } catch {
            print("[Moderation] report failed:", error)
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: - Account deletion

    enum DeletionError: LocalizedError {
        case notSignedIn
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "You're not signed in."
            case .failed(let m): return m
            }
        }
    }

    /// Delete the account and everything attached to it.
    ///
    /// Server-side by necessity: security rules forbid a client from deleting
    /// the copy of a friendship that lives on someone else's profile, and
    /// they should. The function removes those, anonymises games so opponents
    /// aren't left with a dangling name, then deletes the Auth record last so
    /// a failure part-way through is retryable.
    func deleteAccount() async throws {
        #if canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        guard RemoteBootstrap.isFirebaseConfigured,
              Auth.auth().currentUser != nil else { throw DeletionError.notSignedIn }
        do {
            _ = try await Functions.functions(region: "us-central1")
                .httpsCallable("deleteAccount")
                .call()
        } catch {
            throw DeletionError.failed(error.localizedDescription)
        }
        // The Auth record is gone; clear local session state.
        try? Auth.auth().signOut()
        stop()
        #else
        throw DeletionError.notSignedIn
        #endif
    }
}
