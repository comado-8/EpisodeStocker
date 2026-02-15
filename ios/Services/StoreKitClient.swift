import Foundation
import StoreKit

struct StoreKitProductInfo: Equatable {
    let id: String
    let displayName: String
    let displayPrice: String
}

enum StoreKitPurchaseState: Equatable {
    case purchased(productID: String)
    case userCancelled
    case pending
}

enum StoreKitClientError: LocalizedError, Equatable {
    case productNotFound(productID: String)
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound(let productID):
            return "課金商品が見つかりません: \(productID)"
        case .verificationFailed:
            return "課金トランザクションの検証に失敗しました。"
        }
    }
}

protocol StoreKitClient {
    func fetchProducts(ids: [String]) async throws -> [StoreKitProductInfo]
    func purchase(productID: String) async throws -> StoreKitPurchaseState
    func syncPurchases() async throws
    func fetchActiveSubscriptionStatus(monthlyProductID: String, yearlyProductID: String) async throws
        -> SubscriptionStatus
}

struct DefaultStoreKitClient: StoreKitClient {
    func fetchProducts(ids: [String]) async throws -> [StoreKitProductInfo] {
        let products = try await Product.products(for: ids)
        return products.map {
            StoreKitProductInfo(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice)
        }
    }

    func purchase(productID: String) async throws -> StoreKitPurchaseState {
        let products = try await Product.products(for: [productID])
        guard let product = products.first(where: { $0.id == productID }) else {
            throw StoreKitClientError.productNotFound(productID: productID)
        }

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

    func syncPurchases() async throws {
        try await AppStore.sync()
    }

    func fetchActiveSubscriptionStatus(monthlyProductID: String, yearlyProductID: String) async throws
        -> SubscriptionStatus
    {
        let now = Date()
        var latestTransaction: Transaction?

        for await entitlement in Transaction.currentEntitlements {
            let transaction = try checkVerified(entitlement)
            guard transaction.productID == monthlyProductID || transaction.productID == yearlyProductID else {
                continue
            }
            if let revocationDate = transaction.revocationDate, revocationDate <= now {
                continue
            }
            if let expirationDate = transaction.expirationDate, expirationDate <= now {
                continue
            }

            guard let current = latestTransaction else {
                latestTransaction = transaction
                continue
            }

            let currentExpiration = current.expirationDate ?? .distantFuture
            let candidateExpiration = transaction.expirationDate ?? .distantFuture
            if candidateExpiration > currentExpiration {
                latestTransaction = transaction
            }
        }

        guard let latestTransaction else {
            return SubscriptionStatus(plan: .free, expiryDate: nil, trialEndDate: nil)
        }

        let plan: SubscriptionStatus.Plan = latestTransaction.productID == yearlyProductID ? .yearly : .monthly
        let trialEndDate: Date?
        if latestTransaction.offerType == .introductory {
            trialEndDate = latestTransaction.expirationDate
        } else {
            trialEndDate = nil
        }
        return SubscriptionStatus(
            plan: plan,
            expiryDate: latestTransaction.expirationDate,
            trialEndDate: trialEndDate
        )
    }

    private func checkVerified<T>(_ verificationResult: VerificationResult<T>) throws -> T {
        switch verificationResult {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreKitClientError.verificationFailed
        }
    }
}
