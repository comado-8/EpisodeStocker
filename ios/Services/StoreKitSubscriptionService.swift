import Foundation

final class StoreKitSubscriptionService: SubscriptionService {
    private let client: StoreKitClient

    init(client: StoreKitClient = DefaultStoreKitClient()) {
        self.client = client
    }

    func fetchStatus() async throws -> SubscriptionStatus {
        try await client.fetchActiveSubscriptionStatus(
            monthlyProductID: SubscriptionCatalog.monthlyProductID,
            yearlyProductID: SubscriptionCatalog.yearlyProductID
        )
    }

    func fetchProducts() async throws -> [SubscriptionProduct] {
        let products = try await client.fetchProducts(ids: SubscriptionCatalog.allProductIDs)
        let mapped = products.compactMap { productInfo -> SubscriptionProduct? in
            guard let plan = plan(for: productInfo.id) else { return nil }
            return SubscriptionProduct(
                id: productInfo.id,
                displayName: productInfo.displayName,
                displayPrice: productInfo.displayPrice,
                plan: plan
            )
        }

        let order = [SubscriptionCatalog.monthlyProductID, SubscriptionCatalog.yearlyProductID]
        return mapped.sorted { lhs, rhs in
            let left = order.firstIndex(of: lhs.id) ?? Int.max
            let right = order.firstIndex(of: rhs.id) ?? Int.max
            return left < right
        }
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        let state = try await client.purchase(productID: productID)
        switch state {
        case .purchased:
            return .purchased(try await fetchStatus())
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        }
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        try await client.syncPurchases()
        return try await fetchStatus()
    }

    private func plan(for productID: String) -> SubscriptionStatus.Plan? {
        SubscriptionCatalog.plan(for: productID)
    }
}
