import SwiftUI
import UIKit

@main
struct SCRIBBLDApp: App {
    @UIApplicationDelegateAdaptor(SCRIBBLDAppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var store = StoreManager()
    @StateObject private var auth = AuthService()
    @StateObject private var friends = FriendsService()
    @StateObject private var invites = InvitesService()
    @State private var pendingInvite: PendingInvite?

    init() {
        RemoteBootstrap.configure()
        #if DEBUG
        let caveat = UIFont.fontNames(forFamilyName: "Caveat")
        let dmSans = UIFont.fontNames(forFamilyName: "DM Sans")
        print("[SCRIBBLD] Caveat faces: \(caveat)")
        print("[SCRIBBLD] DM Sans faces: \(dmSans)")
        print("[SCRIBBLD] Remote configured: \(RemoteBootstrap.isFirebaseConfigured)")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(store)
                .environmentObject(auth)
                .environmentObject(friends)
                .environmentObject(invites)
                .preferredColorScheme(.light)
                .task {
                    auth.bootstrap()
                    AdTrackingPermission.bumpLaunchCount()
                    // Spec: ATT prompt on the SECOND launch, not the first,
                    // so users see at least one screen of value before being
                    // asked to allow tracking.
                    Task { await AdTrackingPermission.requestIfDue() }
                    RewardedAdService.shared.preload()
                }
                .onChange(of: auth.account?.uid) { _, uid in
                    if let uid {
                        friends.observe(for: uid)
                        invites.observe(uid: uid)
                        ModerationService.shared.observeBlocks(uid: uid)
                        // Binds this device's FCM token to the signed-in
                        // account. Nothing else calls this, so without it no
                        // token is ever written and no push can be delivered.
                        PushService.shared.bind(to: uid)
                    } else {
                        friends.stop()
                        invites.stop()
                        ModerationService.shared.stop()
                    }
                }
                // Universal Link tap (https://scribbld-prod.firebaseapp.com/i/<id>).
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        handleIncomingURL(url)
                    }
                }
                // Custom scheme tap (scribbld://i/<id>) — used as the
                // belt-and-suspenders fallback from the hosted landing
                // page when the universal link doesn't trigger.
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .sheet(item: $pendingInvite) { invite in
                    // CRITICAL: SwiftUI `.sheet` does NOT auto-propagate
                    // env objects from the parent. The joiner navigates
                    // from IncomingInviteView → Live*View inside this
                    // sheet, and the Live views render BannerAdView,
                    // which reads `store` via @EnvironmentObject. If
                    // it's not injected here, the joiner crashes with
                    // `EnvironmentObject.error()`. Inject every env
                    // object the live + post-game flows might consume.
                    IncomingInviteView(invite: invite)
                        .environmentObject(appState)
                        .environmentObject(store)
                        .environmentObject(auth)
                        .environmentObject(friends)
                        .environmentObject(invites)
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard let invite = PendingInvite.parse(url) else {
            #if DEBUG
            print("[SCRIBBLD] Ignored unrecognized URL:", url.absoluteString)
            #endif
            return
        }
        pendingInvite = invite
    }
}

extension PendingInvite: Identifiable {
    var id: String { gameId }
}
