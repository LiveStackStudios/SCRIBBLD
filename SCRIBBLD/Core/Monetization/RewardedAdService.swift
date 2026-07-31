import Foundation
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Single-purpose rewarded ad loader used by the Sketching screen to let
/// free users unlock a brush or color for one session in exchange for
/// watching a 15s ad.
@MainActor
final class RewardedAdService: NSObject, ObservableObject {
    static let shared = RewardedAdService()

    @Published private(set) var isReady: Bool = false

    #if canImport(GoogleMobileAds)
    private var ad: GADRewardedAd?
    #endif

    func preload() {
        #if canImport(GoogleMobileAds)
        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: AdConfig.Rewarded.sketchUnlock, request: request) { [weak self] ad, error in
            if let error {
                print("[Rewarded] preload failed:", error)
                self?.isReady = false
                return
            }
            self?.ad = ad
            self?.isReady = true
        }
        #endif
    }

    /// Show the ad. `onReward` fires only if the user actually completes
    /// the view (we never grant the unlock on user dismissal).
    func present(from controller: UIViewController, onReward: @escaping () -> Void) {
        #if canImport(GoogleMobileAds)
        guard let ad else {
            print("[Rewarded] no ad ready — preloading and skipping")
            preload()
            return
        }
        ad.present(fromRootViewController: controller) {
            onReward()
        }
        self.ad = nil
        isReady = false
        preload()
        #endif
    }
}
