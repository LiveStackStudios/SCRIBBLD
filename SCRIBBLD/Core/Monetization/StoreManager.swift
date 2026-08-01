import Foundation
import SwiftUI

@MainActor
final class StoreManager: ObservableObject {
    enum ProductID: String, CaseIterable {
        case monthlySubscription = "com.livestackstudios.scribbld.inkpro.monthly"
        case annualSubscription  = "com.livestackstudios.scribbld.inkpro.annual"
    }

    struct Offering: Identifiable, Hashable {
        var id: ProductID
        var headline: String
        var price: String
        var perUnit: String
        var badge: String?
        var savings: String?
    }

    /// SCRIBBLD 1.0 ships **free, with no in-app purchases**. Every premium
    /// feature is unlocked for everyone and the paywall is unreachable.
    ///
    /// This is deliberately NOT done by setting `status = .inkPro`: that would
    /// also hide the banner ads (see `BannerAdView`), which are the app's only
    /// revenue in 1.0. Status stays `.free` so ads keep showing.
    ///
    /// Flip to `false` when real StoreKit 2 and a server-verified entitlement
    /// land — see `memory/project_storekit_entitlement_todo.md`.
    static let allPremiumFreeInV1 = true

    /// Single place the UI asks "should premium content be available?".
    var premiumUnlocked: Bool { Self.allPremiumFreeInV1 || status.isPro }

    @Published var status: SubscriptionStatus = .free
    @Published var sessionUnlocks: Set<String> = []

    /// Static offerings until real StoreKit products are configured on ASC.
    let offerings: [Offering] = [
        .init(id: .monthlySubscription, headline: "1 MONTH",   price: "$1.99",  perUnit: "/mo", badge: nil,          savings: nil),
        .init(id: .annualSubscription,  headline: "12 MONTHS", price: "$14.99", perUnit: "/yr", badge: "BEST VALUE", savings: "SAVE 37%")
    ]

    /// No-op in 1.0. This used to sleep briefly and then set `status = .inkPro`,
    /// i.e. it granted a paid entitlement with no payment sheet — which is a
    /// Guideline 2.1 rejection the moment a reviewer taps it. The paywall is
    /// unreachable in 1.0; this stays inert until real StoreKit 2 lands so the
    /// deceptive path cannot come back by accident.
    func purchase(_ id: ProductID) async {
        assertionFailure("purchase() called but StoreKit is not implemented — the paywall should be unreachable in 1.0")
    }

    func startTrial() async {
        assertionFailure("startTrial() called but StoreKit is not implemented")
    }

    func restore() async {
        try? await Task.sleep(nanoseconds: 250_000_000)
    }

    func unlockForSession(_ key: String) {
        sessionUnlocks.insert(key)
    }

    func isUnlocked(_ key: String) -> Bool {
        premiumUnlocked || sessionUnlocks.contains(key)
    }
}
