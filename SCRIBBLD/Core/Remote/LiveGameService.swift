import Foundation
import SwiftUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Game type identifier shared between client and Firestore.
enum LiveGameKind: String, Codable {
    case ticTacToe, dotsAndBoxes, hangman, stop

    var displayName: String {
        switch self {
        case .ticTacToe:    return "Tic Tac Toe"
        case .dotsAndBoxes: return "Dots & Boxes"
        case .hangman:      return "Hangman"
        case .stop:         return "Stop!"
        }
    }
}

/// Status of a live game's Firestore doc.
enum LiveGameStatus: String, Codable {
    case pending    // created by inviter, waiting for opponent to accept
    case active     // both players in, gameplay underway
    case completed
    case abandoned
}

/// Common shape that lives at `games/{gameId}` — game-specific state is
/// blobbed into the `state` map so each game module owns its schema.
struct LiveGameDoc {
    var id: String
    var type: LiveGameKind
    var status: LiveGameStatus
    var players: [String]                  // ordered; index 0 is host
    var playerNames: [String: String]      // uid → display name
    var currentTurn: String                // uid whose move it is
    var state: [String: Any]               // game-specific blob
    var winner: String?                    // uid or "draw"
    var createdAt: Date
    var updatedAt: Date
    /// Cap on `players.size()`. Defaults to 2 for legacy docs written
    /// before this field existed.
    var maxPlayers: Int

    func opponentUID(of uid: String) -> String? {
        players.first(where: { $0 != uid })
    }
}

/// Creating, joining, observing live games. Game-specific view models call
/// `observe(_:)` for live state and `applyMove(_:transaction:)` to write.
@MainActor
final class LiveGameService: ObservableObject {
    static let shared = LiveGameService()

    @Published private(set) var currentGame: LiveGameDoc?

    #if canImport(FirebaseFirestore)
    private var listener: ListenerRegistration?
    #endif

    // MARK: - Create / accept

    /// Creator opens a game, writes an invite to opponent. Returns gameId.
    func createInvite(
        kind: LiveGameKind,
        from: AuthAccount,
        to opponentUID: String,
        opponentName: String,
        initialState: [String: Any],
        maxPlayers: Int
    ) async -> String? {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { return nil }
        let db = Firestore.firestore()
        let gameRef = db.collection("games").document()
        let gameId = gameRef.documentID
        let now = Date()

        let players = [from.uid, opponentUID]
        let names = [from.uid: from.displayName, opponentUID: opponentName]

        let gameDoc: [String: Any] = [
            "type": kind.rawValue,
            "status": LiveGameStatus.pending.rawValue,
            "players": players,
            "playerNames": names,
            "currentTurn": from.uid,
            "state": initialState,
            "winner": NSNull(),
            "createdAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now),
            // Per-friend invites previously had no expiry at all, so every
            // game ever started this way lived in Firestore forever.
            "expiresAt": Timestamp(date: LiveGameService.expiry(for: .pending, from: now)),
            "maxPlayers": maxPlayers,
            "inviteKind": "friend"
        ]

        let inviteRef = db.collection("users").document(opponentUID)
            .collection("invites").document(gameId)
        let inviteDoc: [String: Any] = [
            "type": kind.rawValue,
            "from": from.uid,
            "fromName": from.displayName,
            "gameId": gameId,
            "status": "pending",
            "createdAt": Timestamp(date: now)
        ]

        do {
            let batch = db.batch()
            batch.setData(gameDoc, forDocument: gameRef)
            batch.setData(inviteDoc, forDocument: inviteRef)
            try await batch.commit()
            return gameId
        } catch {
            print("[LiveGame] createInvite error:", error)
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Opponent accepts an invite — game moves from pending → active and
    /// the invite is deleted.
    func acceptInvite(gameId: String, uid: String) async {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { return }
        let db = Firestore.firestore()
        let gameRef = db.collection("games").document(gameId)
        let inviteRef = db.collection("users").document(uid)
            .collection("invites").document(gameId)
        do {
            let batch = db.batch()
            batch.updateData([
                "status": LiveGameStatus.active.rawValue,
                "updatedAt": Timestamp(date: Date()),
                // Push the delete-after stamp out from the short invite
                // window to the active-game window, so a game in progress
                // isn't swept 24h after it was created.
                "expiresAt": Timestamp(date: LiveGameService.expiry(for: .active))
            ], forDocument: gameRef)
            batch.deleteDocument(inviteRef)
            try await batch.commit()
        } catch {
            print("[LiveGame] accept error:", error)
        }
        #endif
    }

    // MARK: - Share-link (open) invites
    //
    // Open invites have no known recipient at create-time. The creator
    // writes only themselves into `players`; the doc carries an
    // `expiresAt` timestamp so Firestore TTL sweeps unclaimed games after
    // 24h. The Firestore rules let any signed-in user append themselves
    // to a pending solo game exactly once.

    /// Default TTL for share-link invites — Firestore TTL sweeps the doc
    /// if it's still pending after this window.
    static let openInviteTTL: TimeInterval = 60 * 60 * 24

    /// How long a game doc outlives its last write, by status. A Firestore
    /// TTL policy on `games.expiresAt` does the actual deleting (it sweeps
    /// within ~24h *after* the stamp, so treat these as a floor, not an
    /// exact deletion time).
    ///
    /// Every write path must stamp this. A doc with no `expiresAt` is
    /// invisible to the TTL policy and lives forever — that's how the
    /// pre-2026-07-30 games accumulated.
    static let pendingInviteTTL: TimeInterval = 60 * 60 * 24        // unclaimed invite
    static let activeGameTTL: TimeInterval    = 60 * 60 * 24 * 7    // 7 days idle; refreshed on every move
    static let finishedGameTTL: TimeInterval  = 60 * 60 * 24        // kept briefly for the post-game screen

    static func ttl(for status: LiveGameStatus) -> TimeInterval {
        switch status {
        case .pending:               return pendingInviteTTL
        case .active:                return activeGameTTL
        case .completed, .abandoned: return finishedGameTTL
        }
    }

    /// Delete-after date for a doc entering `status` right now. Callers wrap
    /// this in a `Timestamp` inside their Firestore-guarded blocks.
    static func expiry(for status: LiveGameStatus, from now: Date = Date()) -> Date {
        now.addingTimeInterval(ttl(for: status))
    }

    /// Create a game doc with a single player + 24h expiry. Returns the
    /// gameId for embedding in the universal link.
    func createOpenInvite(
        kind: LiveGameKind,
        from: AuthAccount,
        initialState: [String: Any],
        maxPlayers: Int
    ) async -> String? {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { return nil }
        let db = Firestore.firestore()
        let gameRef = db.collection("games").document()
        let now = Date()
        let expiresAt = LiveGameService.expiry(for: .pending, from: now)

        let doc: [String: Any] = [
            "type": kind.rawValue,
            "status": LiveGameStatus.pending.rawValue,
            "players": [from.uid],
            "playerNames": [from.uid: from.displayName],
            "currentTurn": from.uid,
            "state": initialState,
            "winner": NSNull(),
            "createdAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now),
            "expiresAt": Timestamp(date: expiresAt),
            "maxPlayers": maxPlayers,
            "inviteKind": "open"
        ]

        do {
            try await gameRef.setData(doc)
            return gameRef.documentID
        } catch {
            print("[LiveGame] createOpenInvite error:", error)
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Joiner takes the open slot. Transactional so two concurrent taps
    /// can't both think they made it in.
    ///
    /// Status transition policy:
    /// - For `maxPlayers == 2` games (TTT, D&B, Hangman): the joiner is
    ///   the second and final player → flip `status` to `active`
    ///   immediately so play starts on the next snapshot delivery.
    /// - For `maxPlayers > 2` games (Stop! today; any future N-player
    ///   game): the joiner just appends themselves. Status stays
    ///   `pending` until the host taps Start via `startLobbyGame`.
    ///   This gives the host control over when the lobby closes.
    func joinOpenInvite(gameId: String, joiner: AuthAccount) async throws -> LiveGameKind? {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { return nil }
        let db = Firestore.firestore()
        let ref = db.collection("games").document(gameId)
        var resolvedKind: LiveGameKind?

        _ = try await db.runTransaction { transaction, errorPointer -> Any? in
            let snap: DocumentSnapshot
            do { snap = try transaction.getDocument(ref) }
            catch let error as NSError { errorPointer?.pointee = error; return nil }
            guard let data = snap.data() else {
                errorPointer?.pointee = NSError(
                    domain: "LiveGame",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Game not found or already expired."]
                )
                return nil
            }
            guard (data["status"] as? String) == LiveGameStatus.pending.rawValue else {
                errorPointer?.pointee = NSError(
                    domain: "LiveGame",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "This game already started."]
                )
                return nil
            }
            // Mirrors the security rule: only share-link ("open") games are
            // joinable by gameId, and only until they expire. A per-friend
            // invite to an N-player game also sits pending with free slots,
            // but a forwarded link must not drop a stranger into it.
            guard (data["inviteKind"] as? String) == "open" else {
                errorPointer?.pointee = NSError(
                    domain: "LiveGame",
                    code: 403,
                    userInfo: [NSLocalizedDescriptionKey: "This invite is for someone else."]
                )
                return nil
            }
            if let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue(), expiresAt < Date() {
                errorPointer?.pointee = NSError(
                    domain: "LiveGame",
                    code: 410,
                    userInfo: [NSLocalizedDescriptionKey: "This invite link has expired."]
                )
                return nil
            }
            var players = (data["players"] as? [String]) ?? []
            // Legacy 2-player games written before maxPlayers field existed
            // implicitly cap at 2.
            let maxPlayers = (data["maxPlayers"] as? Int) ?? 2
            guard players.count < maxPlayers else {
                errorPointer?.pointee = NSError(
                    domain: "LiveGame",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "This game is already full."]
                )
                return nil
            }
            guard !players.contains(joiner.uid) else {
                errorPointer?.pointee = NSError(
                    domain: "LiveGame",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "You're already in this game."]
                )
                return nil
            }
            players.append(joiner.uid)
            var names = (data["playerNames"] as? [String: String]) ?? [:]
            names[joiner.uid] = joiner.displayName
            if let kindRaw = data["type"] as? String,
               let kind = LiveGameKind(rawValue: kindRaw) {
                resolvedKind = kind
            }

            var patch: [String: Any] = [
                "players": players,
                "playerNames": names,
                "updatedAt": Timestamp(date: Date())
            ]
            // Auto-active when the game cap is 2 (joiner fills the only
            // remaining slot). N>2 games wait for the host's Start tap.
            if maxPlayers == 2 {
                patch["status"] = LiveGameStatus.active.rawValue
                patch["expiresAt"] = Timestamp(date: LiveGameService.expiry(for: .active))
            } else {
                // Still a lobby — extend the invite window so a filling
                // lobby doesn't expire out from under the host.
                patch["expiresAt"] = Timestamp(date: LiveGameService.expiry(for: .pending))
            }
            transaction.updateData(patch, forDocument: ref)
            return nil
        }
        return resolvedKind
        #else
        return nil
        #endif
    }

    /// Host-only transition from lobby (`pending`) to gameplay (`active`)
    /// for N-player games. Caller must be the first uid in `players`
    /// (the inviter) and at least one other player must have joined.
    func startLobbyGame(gameId: String, host: AuthAccount) async throws {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { return }
        let db = Firestore.firestore()
        let ref = db.collection("games").document(gameId)
        _ = try await db.runTransaction { transaction, errorPointer -> Any? in
            let snap: DocumentSnapshot
            do { snap = try transaction.getDocument(ref) }
            catch let error as NSError { errorPointer?.pointee = error; return nil }
            guard let data = snap.data() else {
                errorPointer?.pointee = NSError(
                    domain: "LiveGame", code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Game not found."])
                return nil
            }
            guard (data["status"] as? String) == LiveGameStatus.pending.rawValue else {
                errorPointer?.pointee = NSError(
                    domain: "LiveGame", code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "Game has already started."])
                return nil
            }
            let players = (data["players"] as? [String]) ?? []
            guard players.first == host.uid else {
                errorPointer?.pointee = NSError(
                    domain: "LiveGame", code: 403,
                    userInfo: [NSLocalizedDescriptionKey: "Only the host can start the game."])
                return nil
            }
            guard players.count >= 2 else {
                errorPointer?.pointee = NSError(
                    domain: "LiveGame", code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "Need at least one other player to start."])
                return nil
            }
            var state = (data["state"] as? [String: Any]) ?? [:]
            // For Stop!, mark the moment the lobby closed so the
            // per-round countdown can start from this server timestamp.
            state["startedAt"] = Timestamp(date: Date())
            transaction.updateData([
                "status": LiveGameStatus.active.rawValue,
                "state": state,
                "updatedAt": Timestamp(date: Date()),
                "expiresAt": Timestamp(date: LiveGameService.expiry(for: .active))
            ], forDocument: ref)
            return nil
        }
        #endif
    }

    /// Inviter cancels a still-pending solo open invite. Safe to call
    /// repeatedly — silently no-ops if the doc isn't ours anymore.
    func cancelOpenInvite(gameId: String, uid: String) async {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { return }
        let db = Firestore.firestore()
        let ref = db.collection("games").document(gameId)
        do {
            let snap = try await ref.getDocument()
            guard let data = snap.data(),
                  (data["status"] as? String) == LiveGameStatus.pending.rawValue,
                  let players = data["players"] as? [String],
                  players == [uid] else { return }
            try await ref.delete()
        } catch {
            print("[LiveGame] cancelOpenInvite error:", error)
        }
        #endif
    }

    // MARK: - My pending lobbies (host re-entry)

    #if canImport(FirebaseFirestore)
    private var myPendingListener: ListenerRegistration?
    #endif

    /// Observe games where the current user is a participant AND the
    /// game is still pending. Used by Friends tab "Your open lobbies"
    /// to give the host a way to re-enter a share-link lobby they
    /// already created (and any pending friend invites they're a
    /// joiner on too). Snapshot keeps the section live as games
    /// transition pending → active → completed.
    func observeMyPendingGames(uid: String, onChange: @escaping ([LiveGameDoc]) -> Void) {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { onChange([]); return }
        myPendingListener?.remove()
        let db = Firestore.firestore()
        myPendingListener = db.collection("games")
            .whereField("players", arrayContains: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snap, _ in
                let docs = (snap?.documents ?? []).compactMap { doc -> LiveGameDoc? in
                    let data = doc.data()
                    guard let typeRaw = data["type"] as? String,
                          let kind = LiveGameKind(rawValue: typeRaw) else { return nil }
                    return LiveGameDoc(
                        id: doc.documentID,
                        type: kind,
                        status: LiveGameStatus(rawValue: (data["status"] as? String) ?? "") ?? .pending,
                        players: (data["players"] as? [String]) ?? [],
                        playerNames: (data["playerNames"] as? [String: String]) ?? [:],
                        currentTurn: (data["currentTurn"] as? String) ?? "",
                        state: (data["state"] as? [String: Any]) ?? [:],
                        winner: data["winner"] as? String,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
                        maxPlayers: (data["maxPlayers"] as? Int) ?? 2
                    )
                }
                // Newest pending first — most likely to be the lobby
                // the host just left.
                let sorted = docs.sorted { $0.updatedAt > $1.updatedAt }
                Task { @MainActor in onChange(sorted) }
            }
        #else
        onChange([])
        #endif
    }

    func stopObservingMyPendingGames() {
        #if canImport(FirebaseFirestore)
        myPendingListener?.remove()
        myPendingListener = nil
        #endif
    }

    func declineInvite(gameId: String, uid: String) async {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { return }
        let db = Firestore.firestore()
        let batch = db.batch()
        batch.updateData([
            "status": LiveGameStatus.abandoned.rawValue
        ], forDocument: db.collection("games").document(gameId))
        batch.deleteDocument(db.collection("users").document(uid)
            .collection("invites").document(gameId))
        try? await batch.commit()
        #endif
    }

    // MARK: - Observe / write

    func observe(gameId: String, onChange: @escaping (LiveGameDoc?) -> Void) {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { onChange(nil); return }
        listener?.remove()
        let db = Firestore.firestore()
        listener = db.collection("games").document(gameId)
            .addSnapshotListener { [weak self] snap, _ in
                guard let data = snap?.data() else {
                    Task { @MainActor in onChange(nil) }
                    return
                }
                let doc = LiveGameDoc(
                    id: snap?.documentID ?? gameId,
                    type: LiveGameKind(rawValue: (data["type"] as? String) ?? "") ?? .ticTacToe,
                    status: LiveGameStatus(rawValue: (data["status"] as? String) ?? "") ?? .pending,
                    players: (data["players"] as? [String]) ?? [],
                    playerNames: (data["playerNames"] as? [String: String]) ?? [:],
                    currentTurn: (data["currentTurn"] as? String) ?? "",
                    state: (data["state"] as? [String: Any]) ?? [:],
                    winner: data["winner"] as? String,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
                    maxPlayers: (data["maxPlayers"] as? Int) ?? 2
                )
                Task { @MainActor in
                    self?.currentGame = doc
                    onChange(doc)
                }
            }
        #else
        onChange(nil)
        #endif
    }

    func stopObserving() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        #endif
        currentGame = nil
    }

    /// Transactional update: read game doc, hand it to `mutate`, write the
    /// modified state back. `mutate` returns the partial update map, or nil
    /// to skip writing.
    func applyMove(
        gameId: String,
        mutate: @escaping (LiveGameDoc) -> [String: Any]?
    ) async throws {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { return }
        let db = Firestore.firestore()
        let ref = db.collection("games").document(gameId)
        _ = try await db.runTransaction { transaction, errorPointer -> Any? in
            let snap: DocumentSnapshot
            do { snap = try transaction.getDocument(ref) }
            catch let error as NSError { errorPointer?.pointee = error; return nil }
            guard let data = snap.data() else {
                errorPointer?.pointee = NSError(domain: "LiveGame", code: 404, userInfo: [NSLocalizedDescriptionKey: "Game not found"])
                return nil
            }
            let doc = LiveGameDoc(
                id: ref.documentID,
                type: LiveGameKind(rawValue: (data["type"] as? String) ?? "") ?? .ticTacToe,
                status: LiveGameStatus(rawValue: (data["status"] as? String) ?? "") ?? .pending,
                players: (data["players"] as? [String]) ?? [],
                playerNames: (data["playerNames"] as? [String: String]) ?? [:],
                currentTurn: (data["currentTurn"] as? String) ?? "",
                state: (data["state"] as? [String: Any]) ?? [:],
                winner: data["winner"] as? String,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
                maxPlayers: (data["maxPlayers"] as? Int) ?? 2
            )
            if var patch = mutate(doc) {
                let now = Date()
                patch["updatedAt"] = Timestamp(date: now)
                // Every move refreshes the delete-after stamp, so a game
                // being actively played never expires, and the moment a
                // move ends the game the doc is scheduled for cleanup.
                let resulting = (patch["status"] as? String)
                    .flatMap(LiveGameStatus.init(rawValue:)) ?? doc.status
                patch["expiresAt"] = Timestamp(date: LiveGameService.expiry(for: resulting, from: now))
                transaction.updateData(patch, forDocument: ref)
            }
            return nil
        }
        #endif
    }
}
