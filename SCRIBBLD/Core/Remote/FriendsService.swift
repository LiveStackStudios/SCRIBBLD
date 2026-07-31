import Foundation
import SwiftUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct FriendSummary: Identifiable, Hashable {
    var id: String          // friend's uid
    var displayName: String
    var lastSeen: Date?
    var isOnline: Bool
}

struct FriendRequest: Identifiable, Hashable {
    var id: String          // request doc id
    var fromUID: String
    var fromName: String
    var createdAt: Date
}

@MainActor
final class FriendsService: ObservableObject {
    @Published private(set) var friends: [FriendSummary] = []
    @Published private(set) var incomingRequests: [FriendRequest] = []
    @Published private(set) var searchResults: [FriendSummary] = []
    @Published var searchQuery: String = ""

    #if canImport(FirebaseFirestore)
    private var friendsListener: ListenerRegistration?
    private var requestsListener: ListenerRegistration?
    #endif

    private var currentUID: String?

    func observe(for uid: String) {
        currentUID = uid
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { return }
        let db = Firestore.firestore()
        friendsListener?.remove()
        requestsListener?.remove()
        friendsListener = db.collection("users").document(uid).collection("friends")
            .addSnapshotListener { [weak self] snapshot, _ in
                let docs = snapshot?.documents ?? []
                Task { @MainActor in
                    self?.friends = docs.compactMap { doc in
                        let data = doc.data()
                        return FriendSummary(
                            id: doc.documentID,
                            displayName: (data["displayName"] as? String) ?? "Friend",
                            lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue(),
                            isOnline: (data["isOnline"] as? Bool) ?? false
                        )
                    }
                }
            }
        requestsListener = db.collection("users").document(uid).collection("friendRequests")
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, _ in
                let docs = snapshot?.documents ?? []
                Task { @MainActor in
                    self?.incomingRequests = docs.compactMap { doc in
                        let data = doc.data()
                        return FriendRequest(
                            id: doc.documentID,
                            fromUID: (data["fromUID"] as? String) ?? "",
                            fromName: (data["fromName"] as? String) ?? "Friend",
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        )
                    }
                }
            }
        #endif
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        friendsListener?.remove(); friendsListener = nil
        requestsListener?.remove(); requestsListener = nil
        #endif
        friends = []
        incomingRequests = []
        searchResults = []
        currentUID = nil
    }

    func search(_ query: String) async {
        searchQuery = query
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { return }
        guard query.count >= 2 else { searchResults = []; return }
        let db = Firestore.firestore()
        do {
            let snap = try await db.collection("users")
                .whereField("displayName", isGreaterThanOrEqualTo: query)
                .whereField("displayName", isLessThan: query + "\u{f8ff}")
                .limit(to: 20)
                .getDocuments()
            self.searchResults = snap.documents.compactMap { doc in
                guard doc.documentID != currentUID else { return nil }
                let data = doc.data()
                return FriendSummary(
                    id: doc.documentID,
                    displayName: (data["displayName"] as? String) ?? "Friend",
                    lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue(),
                    isOnline: false
                )
            }
        } catch {
            print("[Friends] search error:", error)
        }
        #endif
    }

    func sendRequest(to targetUID: String, myName: String) async {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured, let me = currentUID else { return }
        let db = Firestore.firestore()
        try? await db.collection("users").document(targetUID)
            .collection("friendRequests").document(me)
            .setData([
                "fromUID": me,
                "fromName": myName,
                "status": "pending",
                "createdAt": Timestamp(date: Date())
            ])
        #endif
    }

    func accept(_ request: FriendRequest, myName: String) async {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured, let me = currentUID else { return }
        // The peer is the request's document ID, never the body's `fromUID`:
        // rules pin the doc ID to the sender's uid, but the body is free-form,
        // so trusting it would let a sender friend the accepter to a third party.
        let peer = request.id
        guard peer != me, !peer.isEmpty else { return }
        let db = Firestore.firestore()
        let batch = db.batch()
        let myRequest = db.collection("users").document(me).collection("friendRequests").document(peer)
        // Delete rather than mark accepted: nothing reads an accepted request
        // (the listener filters on status == pending), so leaving it behind
        // just grows the subcollection forever.
        batch.deleteDocument(myRequest)
        let myFriendDoc = db.collection("users").document(me).collection("friends").document(peer)
        batch.setData(["displayName": request.fromName, "addedAt": Timestamp(date: Date())], forDocument: myFriendDoc)
        let theirFriendDoc = db.collection("users").document(peer).collection("friends").document(me)
        batch.setData(["displayName": myName, "addedAt": Timestamp(date: Date())], forDocument: theirFriendDoc)
        try? await batch.commit()
        #endif
    }

    func reject(_ request: FriendRequest) async {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured, let me = currentUID else { return }
        let db = Firestore.firestore()
        try? await db.collection("users").document(me).collection("friendRequests").document(request.id)
            .updateData(["status": "rejected"])
        #endif
    }
}
