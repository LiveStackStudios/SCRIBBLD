import Foundation

enum SubscriptionStatus: Equatable {
    case free
    case trial(daysRemaining: Int)
    case inkPro

    var isPro: Bool {
        switch self {
        case .free: return false
        case .trial, .inkPro: return true
        }
    }
}
