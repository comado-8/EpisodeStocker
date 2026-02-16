import Foundation
import StoreKit

extension DefaultStoreKitClient {
    static func liveFetchProducts(ids: [String]) async throws -> [StoreKitProductInfo] {
        let products = try await Product.products(for: ids)
        return products.map {
            StoreKitProductInfo(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice)
        }
    }

    static func livePurchase(productID: String) async throws -> StoreKitPurchaseState {
        let products = try await Product.products(for: [productID])
        guard let product = products.first(where: { $0.id == productID }) else {
            throw StoreKitClientError.productNotFound(productID: productID)
        }
        return try await purchase(product: product)
    }

    static func liveSyncPurchases() async throws {
        try await AppStore.sync()
    }

    static func liveFetchEntitlements() async throws -> [StoreKitEntitlementInfo] {
        var entitlements: [StoreKitEntitlementInfo] = []
        for await entitlement in Transaction.currentEntitlements {
            let transaction = try checkVerified(entitlement)
            entitlements.append(
                StoreKitEntitlementInfo(
                    productID: transaction.productID,
                    expirationDate: transaction.expirationDate,
                    revocationDate: transaction.revocationDate,
                    offerType: offerType(from: transaction.offerType)
                )
            )
        }
        return entitlements
    }

    private static func purchase(product: Product) async throws -> StoreKitPurchaseState {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return .purchased(productID: transaction.productID)
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    private static func offerType(from transactionOfferType: Transaction.OfferType?) -> StoreKitOfferType? {
        switch transactionOfferType {
        case .introductory:
            return .introductory
        case .promotional:
            return .promotional
        case .code:
            return .code
        default:
            return nil
        }
    }

    private static func checkVerified<T>(_ verificationResult: VerificationResult<T>) throws -> T {
        switch verificationResult {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreKitClientError.verificationFailed
        }
    }
}
