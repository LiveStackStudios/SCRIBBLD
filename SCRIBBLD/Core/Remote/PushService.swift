import Foundation
import UIKit

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Wraps APNs registration + FCM token persistence so the rest of the app
/// doesn't have to import FirebaseMessaging directly. Safe to call without
/// the Firebase plist — registration is skipped until Firebase is configured.
///
/// The token lives at `users/{uid}/private/push`, NOT on the profile doc:
/// `users/{uid}` is readable by every signed-in user so friend search works,
/// and an FCM token is a stable per-install identifier that shouldn't be
/// harvestable by anyone who can run a name search.
@MainActor
final class PushService: NSObject, ObservableObject {
    static let shared = PushService()

    /// Last token APNs/FCM handed us this launch. Kept so a sign-in that
    /// happens *after* registration can still bind the device to the new
    /// account without waiting for a token rotation.
    private var cachedToken: String?

    // MARK: - Registration

    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            print("[Push] auth error:", error)
        }
    }

    func registerToken(_ deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().token { token, error in
            if let error = error { print("[Push] FCM token error:", error) }
            guard let token else { return }
            Task { @MainActor in
                self.cachedToken = token
                self.persistToken(token)
            }
        }
        #endif
    }

    // MARK: - Account binding

    /// Bind this device to `uid`. Called on every sign-in and on launch while
    /// signed in — asks for notification permission if it hasn't been granted
    /// yet, and re-persists an already-issued token under the new account.
    func bind(to uid: String) {
        Task { await requestAuthorizationAndRegister() }
        if let cachedToken { persistToken(cachedToken, for: uid) }
    }

    /// Unbind before signing out, so pushes for the departing account stop
    /// landing on this device once someone else signs in on it. Must be
    /// awaited *before* `Auth.signOut()` — the delete needs the outgoing
    /// user's credentials to satisfy the owner-only rule.
    func unbind(from uid: String) async {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { return }
        cachedToken = nil
        try? await Firestore.firestore()
            .collection("users").document(uid)
            .collection("private").document("push")
            .delete()
        #endif
    }

    // MARK: - Persistence

    private func persistToken(_ token: String) {
        #if canImport(FirebaseAuth)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        persistToken(token, for: uid)
        #endif
    }

    private func persistToken(_ token: String, for uid: String) {
        #if canImport(FirebaseFirestore)
        guard RemoteBootstrap.isFirebaseConfigured else { return }
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("private").document("push")
            .setData(["fcmToken": token, "updatedAt": Timestamp(date: Date())], merge: true)
        #endif
    }
}
