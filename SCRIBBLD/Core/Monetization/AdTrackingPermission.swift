import Foundation
import SwiftUI

#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
import AdSupport
#endif

/// App Tracking Transparency prompt orchestration. By Apple guidelines and
/// per the SCRIBBLD spec, we request **on second launch** (not first), so
/// the user has seen at least one screen of value before the system sheet
/// appears. Stored counter lives in UserDefaults.
@MainActor
enum AdTrackingPermission {
    private static let launchCountKey = "scribbld.launchCount"
    private static let promptedKey = "scribbld.attPrompted"

    static func bumpLaunchCount() {
        let count = UserDefaults.standard.integer(forKey: launchCountKey) + 1
        UserDefaults.standard.set(count, forKey: launchCountKey)
    }

    static func requestIfDue() async {
        #if canImport(AppTrackingTransparency)
        guard !UserDefaults.standard.bool(forKey: promptedKey) else { return }
        let count = UserDefaults.standard.integer(forKey: launchCountKey)
        guard count >= 2 else { return }
        // Apple requires the prompt to fire from the main thread.
        let status = await ATTrackingManager.requestTrackingAuthorization()
        print("[ATT] result: \(status.rawValue)")
        UserDefaults.standard.set(true, forKey: promptedKey)
        #endif
    }
}
