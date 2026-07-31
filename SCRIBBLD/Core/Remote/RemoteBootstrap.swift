import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// One-time process bootstrap for the remote stack (Firebase + AdMob).
///
/// Designed to fail gracefully:
/// - If `GoogleService-Info.plist` is missing, `FirebaseApp.configure()` is
///   skipped and `isFirebaseConfigured` stays false. The rest of the app
///   should treat that as "remote services unavailable" — surface UI like
///   "Sign in to challenge friends" instead of crashing.
/// - Google Mobile Ads ships a sandbox app ID in Info.plist, so `start(…)`
///   works in Debug without any real account configuration.
@MainActor
enum RemoteBootstrap {
    static private(set) var isFirebaseConfigured: Bool = false
    static private(set) var didAttemptBootstrap: Bool = false

    static func configure() {
        guard !didAttemptBootstrap else { return }
        didAttemptBootstrap = true

        #if canImport(FirebaseCore)
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           FileManager.default.fileExists(atPath: path) {
            // Order matters: Firebase reads the App Check provider factory
            // during configure(), so installing it afterwards would leave the
            // session's first requests unattested.
            AppCheckBootstrap.installProviderFactory()
            FirebaseApp.configure()
            isFirebaseConfigured = true
            print("[Remote] Firebase configured ✓")
        } else {
            print("[Remote] Firebase plist missing — remote features disabled until GoogleService-Info.plist is added.")
        }
        #endif

        #if canImport(GoogleMobileAds)
        // GoogleMobileAds 11.x still exposes the Objective-C-prefixed type.
        // The Swift-friendly `MobileAds.shared` alias only landed in 12.x.
        GADMobileAds.sharedInstance().start { status in
            print("[Remote] AdMob ready: \(status.adapterStatusesByClassName.count) adapters")
        }
        #endif
    }
}
