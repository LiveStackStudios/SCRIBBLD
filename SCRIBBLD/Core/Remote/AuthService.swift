import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Minimal account model surfaced to the rest of the app.
struct AuthAccount: Hashable, Codable {
    var uid: String
    var displayName: String
    var handle: String?
    var photoURL: URL?
    var createdAt: Date
}

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published private(set) var account: AuthAccount?
    @Published private(set) var isSigningIn: Bool = false
    @Published var lastError: String?

    /// Nonce for the current Sign-in-with-Apple attempt; kept here so we can
    /// validate the Apple response inside the delegate callback.
    private var currentNonce: String?

    var isSignedIn: Bool { account != nil }

    func bootstrap() {
        #if canImport(FirebaseAuth)
        guard RemoteBootstrap.isFirebaseConfigured else { return }
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let user = user else {
                self?.account = nil
                return
            }
            self?.hydrate(from: user)
        }
        #endif
    }

    /// Trigger Sign in with Apple. Returns nothing; success/failure is
    /// observed via the `account` / `lastError` published properties.
    func signInWithApple() {
        #if canImport(FirebaseAuth)
        guard RemoteBootstrap.isFirebaseConfigured else {
            lastError = "Sign-in unavailable: Firebase not configured yet."
            return
        }
        isSigningIn = true
        let nonce = AuthService.randomNonceString()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = AuthService.sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
        #else
        lastError = "FirebaseAuth not linked."
        #endif
    }

    /// Clear the published account after the account itself has already been
    /// deleted server-side. Distinct from `signOut()`: there is no longer an
    /// Auth record to sign out of, and no push token left to unbind — the
    /// Cloud Function removed the whole document tree.
    func forgetLocalSession() async {
        account = nil
        lastError = nil
    }

    func signOut() async {
        #if canImport(FirebaseAuth)
        // Drop this device's push token first — after signOut we no longer
        // have the credentials the owner-only delete rule requires, and a
        // stale token would keep delivering this account's notifications to
        // whoever signs in next.
        if let uid = Auth.auth().currentUser?.uid {
            await PushService.shared.unbind(from: uid)
        }
        try? Auth.auth().signOut()
        #endif
        account = nil
    }

    // MARK: - User doc

    #if canImport(FirebaseAuth)
    private func hydrate(from user: User) {
        let uid = user.uid
        let name = user.displayName ?? account?.displayName ?? "Friend"
        let pending = AuthAccount(
            uid: uid,
            displayName: name,
            handle: nil,
            photoURL: user.photoURL,
            createdAt: user.metadata.creationDate ?? Date()
        )
        account = pending
        // Read or write our Firestore mirror so the rest of the app
        // (friends list, leaderboards) can rely on a stable doc shape.
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)
        userRef.getDocument { [weak self] snapshot, _ in
            if let snapshot, snapshot.exists, let data = snapshot.data() {
                let stored = AuthAccount(
                    uid: uid,
                    displayName: (data["displayName"] as? String) ?? name,
                    handle: data["handle"] as? String,
                    photoURL: (data["photoURL"] as? String).flatMap(URL.init(string:)),
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? pending.createdAt
                )
                Task { @MainActor in
                    // This read can land after a sign-out or an account switch;
                    // without the recheck it would resurrect the previous user.
                    guard Auth.auth().currentUser?.uid == uid else { return }
                    self?.account = stored
                }
            } else {
                userRef.setData([
                    "displayName": name,
                    "createdAt": Timestamp(date: pending.createdAt),
                    "photoURL": pending.photoURL?.absoluteString ?? ""
                ], merge: true)
            }
        }
        #endif
    }
    #endif

    // MARK: - Nonce helpers (Apple-recommended boilerplate)

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            randoms.forEach { random in
                if remaining == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        defer { isSigningIn = false }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            lastError = "Apple sign-in returned an unexpected response."
            return
        }
        // Capture Apple-provided name on first sign-in — Apple only sends this once.
        let givenName = credential.fullName?.givenName ?? ""
        let familyName = credential.fullName?.familyName ?? ""
        let appleName = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")

        #if canImport(FirebaseAuth)
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        Auth.auth().signIn(with: firebaseCredential) { [weak self] result, error in
            if let error = error {
                self?.lastError = error.localizedDescription
                return
            }
            guard let user = result?.user else { return }
            if !appleName.isEmpty, user.displayName != appleName {
                let change = user.createProfileChangeRequest()
                change.displayName = appleName
                change.commitChanges()
            }
            Task { @MainActor in self?.hydrate(from: user) }
        }
        #endif
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isSigningIn = false
        if let asError = error as? ASAuthorizationError, asError.code == .canceled { return }
        lastError = error.localizedDescription
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
