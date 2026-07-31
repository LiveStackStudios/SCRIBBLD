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

    @Published var status: SubscriptionStatus = .free
    @Published var sessionUnlocks: Set<String> = []

    /// Static offerings until real StoreKit products are configured on ASC.
    let offerings: [Offering] = [
        .init(id: .monthlySubscription, headline: "1 MONTH",   price: "$1.99",  perUnit: "/mo", badge: nil,          savings: nil),
        .init(id: .annualSubscription,  headline: "12 MONTHS", price: "$14.99", perUnit: "/yr", badge: "BEST VALUE", savings: "SAVE 37%")
    ]

    func purchase(_ id: ProductID) async {
        // Real StoreKit 2 wiring will go here once products are configured.
        // Until then, just flip the entitlement so paywall flows are testable.
        try? await Task.sleep(nanoseconds: 250_000_000)
        status = .inkPro
        HapticEngine.success()
    }

    func startTrial() async {
        try? await Task.sleep(nanoseconds: 250_000_000)
        status = .trial(daysRemaining: 7)
    }

    func restore() async {
        try? await Task.sleep(nanoseconds: 250_000_000)
    }

    func unlockForSession(_ key: String) {
        sessionUnlocks.insert(key)
    }

    func isUnlocked(_ key: String) -> Bool {
        status.isPro || sessionUnlocks.contains(key)
    }
}
