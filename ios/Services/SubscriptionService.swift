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

enum SubscriptionCatalog {
    static let monthlyProductID = "com.episodestocker.premium.monthly"
    static let yearlyProductID = "com.episodestocker.premium.yearly"

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

protocol SubscriptionService {
    func fetchStatus() async throws -> SubscriptionStatus
    func fetchProducts() async throws -> [SubscriptionProduct]
    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome
    func restorePurchases() async throws -> SubscriptionStatus
}
