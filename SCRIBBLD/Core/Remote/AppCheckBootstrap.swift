import Foundation

#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
import FirebaseCore
#endif

/// Firebase App Check — proves to Firebase that a request came from *this*
/// app on a genuine Apple device, rather than from a script holding the
/// (necessarily public) API key out of `GoogleService-Info.plist`.
///
/// Without it, `firestore.rules` is the only thing standing between an
/// attacker and the database. The rules are solid, but they're written to
/// permit legitimate client behaviour — so anything a real client may do, a
/// script may also do: create open invites, enumerate profiles for friend
/// search, burn quota. App Check removes the whole class.
///
/// **Provider choice:** App Attest only. It's the strongest option and needs
/// a Secure Enclave, which every device that can run iOS 17 has (iPhone XS /
/// XR and later are all A12+), so the DeviceCheck fallback Firebase suggests
/// for older deployment targets would be dead code here.
///
/// **Debug builds** use the debug provider instead — App Attest can't
/// attest a simulator or a development build. It prints a token to the
/// console on first launch that has to be registered once in the Firebase
/// Console (see `CURRENT_STATUS.md` for the walkthrough).
enum AppCheckBootstrap {

    /// Must run BEFORE `FirebaseApp.configure()`. Firebase reads the factory
    /// during configuration; setting it afterwards leaves the first requests
    /// of the session unattested.
    static func installProviderFactory() {
        #if canImport(FirebaseAppCheck)
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        print("[AppCheck] debug provider installed — watch the log for the debug token")
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
        #endif
        #endif
    }
}

#if canImport(FirebaseAppCheck)
/// App Attest for release builds.
final class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}
#endif
