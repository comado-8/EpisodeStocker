import Foundation

struct SubscriptionProduct: Equatable, Identifiable {
    let id: String
    let displayName: String
    let displayPrice: String
    let plan: SubscriptionStatus.Plan
}

enum SubscriptionPurchaseOutcome: Equatable {
    case purchased(SubscriptionStatus)
    case purchasedStatusUnavailable(productID: String)
    case userCancelled
    case pending
}

enum SubscriptionCatalog {
    static let monthlyProductID = "comado.studio.episodestocker.pro.monthly"
    static let yearlyProductID = "comado.studio.episodestocker.pro.yearly"

    static let allProductIDs = [monthlyProductID, yearlyProductID]

    static func plan(for productID: String) -> SubscriptionStatus.Plan? {
        switch productID {
        case monthlyProductID:
            return .monthly
        case yearlyProductID:
            return .yearly
        default:
            return nil
        }
    }
}

/// Subscription domain boundary for status, catalog loading, purchase, and restore.
/// ViewModels use this protocol to keep StoreKit details out of UI state logic.
protocol SubscriptionService {
    func fetchStatus() async throws -> SubscriptionStatus
    func fetchProducts() async throws -> [SubscriptionProduct]
    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome
    func restorePurchases() async throws -> SubscriptionStatus
}
