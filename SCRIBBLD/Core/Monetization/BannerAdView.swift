import SwiftUI
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Banner ad slot — only renders for free-tier users. Bridges to the
/// GoogleMobileAds Objective-C view since the SDK is still ObjC-prefixed in
/// the 11.x series.
struct BannerAdView: View {
    /// Pull from `AdConfig.Banner.home` / `.postGame` / `.sketch`.
    let adUnitID: String
    @EnvironmentObject private var store: StoreManager

    /// The UI test that captures App Store screenshots passes this so the
    /// AdMob *test* banner ("AdMob has a YouTube channel… Test mode") doesn't
    /// end up in store artwork. It only affects that run — the flag is a
    /// launch argument, never set by the shipping app.
    private static let suppressForScreenshots =
        ProcessInfo.processInfo.arguments.contains("-SCRIBBLD_SCREENSHOTS")

    var body: some View {
        if store.status.isPro || Self.suppressForScreenshots {
            EmptyView()
        } else {
            #if canImport(GoogleMobileAds)
            BannerAdRepresentable(adUnitID: adUnitID)
                .frame(width: 320, height: 50)
                .frame(maxWidth: .infinity)
            #else
            EmptyView()
            #endif
        }
    }
}

#if canImport(GoogleMobileAds)
private struct BannerAdRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow)?
            .rootViewController
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        if uiView.adUnitID != adUnitID {
            uiView.adUnitID = adUnitID
            uiView.load(GADRequest())
        }
    }
}
#endif
