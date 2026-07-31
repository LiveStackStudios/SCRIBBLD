import UIKit
import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// UIKit app delegate adapter so we can hook UNUserNotificationCenter +
/// APNs registration. SwiftUI's @main only gives us SceneDelegate-style
/// hooks, so we attach this through @UIApplicationDelegateAdaptor.
final class SCRIBBLDAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            PushService.shared.registerToken(deviceToken)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[APNs] registration failed:", error)
    }

    // Foreground notifications: show banner instead of silently dropping
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
