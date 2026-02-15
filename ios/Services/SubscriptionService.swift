import Foundation

struct SubscriptionProduct: Equatable, Identifiable {
    let id: String
    let displayName: String
    let displayPrice: String
    let plan: SubscriptionStatus.Plan
}

enum SubscriptionPurchaseOutcome: Equatable {
    case purchased(SubscriptionStatus)
    case userCancelled
    case pending
}

protocol SubscriptionService {
    func fetchStatus() async throws -> SubscriptionStatus
    func fetchProducts() async throws -> [SubscriptionProduct]
    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome
    func restorePurchases() async throws -> SubscriptionStatus
}
