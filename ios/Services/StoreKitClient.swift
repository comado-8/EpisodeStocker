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

struct StoreKitEntitlementInfo: Equatable {
    let productID: String
    let expirationDate: Date?
    let revocationDate: Date?
    let offerType: StoreKitOfferType?
}

enum StoreKitOfferType: Equatable {
    case introductory
    case promotional
    case code
}

protocol StoreKitClient {
    func fetchProducts(ids: [String]) async throws -> [StoreKitProductInfo]
    func purchase(productID: String) async throws -> StoreKitPurchaseState
    func syncPurchases() async throws
    func fetchActiveSubscriptionStatus(monthlyProductID: String, yearlyProductID: String) async throws
        -> SubscriptionStatus
}

struct DefaultStoreKitClient: StoreKitClient {
    typealias ProductsLoader = ([String]) async throws -> [StoreKitProductInfo]
    typealias PurchaseHandler = (String) async throws -> StoreKitPurchaseState
    typealias SyncHandler = () async throws -> Void
    typealias EntitlementsLoader = () async throws -> [StoreKitEntitlementInfo]
    typealias DateProvider = () -> Date

    private let productsLoader: ProductsLoader
    private let purchaseHandler: PurchaseHandler
    private let syncHandler: SyncHandler
    private let entitlementsLoader: EntitlementsLoader
    private let dateProvider: DateProvider

    init(
        productsLoader: @escaping ProductsLoader = Self.liveFetchProducts,
        purchaseHandler: @escaping PurchaseHandler = Self.livePurchase,
        syncHandler: @escaping SyncHandler = Self.liveSyncPurchases,
        entitlementsLoader: @escaping EntitlementsLoader = Self.liveFetchEntitlements,
        dateProvider: @escaping DateProvider = Date.init
    ) {
        self.productsLoader = productsLoader
        self.purchaseHandler = purchaseHandler
        self.syncHandler = syncHandler
        self.entitlementsLoader = entitlementsLoader
        self.dateProvider = dateProvider
    }

    func fetchProducts(ids: [String]) async throws -> [StoreKitProductInfo] {
        try await productsLoader(ids)
    }

    func purchase(productID: String) async throws -> StoreKitPurchaseState {
        try await purchaseHandler(productID)
    }

    func syncPurchases() async throws {
        try await syncHandler()
    }

    func fetchActiveSubscriptionStatus(monthlyProductID: String, yearlyProductID: String) async throws
        -> SubscriptionStatus
    {
        let latestEntitlement = try await latestActiveEntitlement(
            monthlyProductID: monthlyProductID,
            yearlyProductID: yearlyProductID
        )

        guard let latestEntitlement else {
            return SubscriptionStatus(plan: .free, expiryDate: nil, trialEndDate: nil)
        }

        let plan: SubscriptionStatus.Plan = latestEntitlement.productID == yearlyProductID ? .yearly : .monthly
        let trialEndDate = latestEntitlement.offerType == .introductory ? latestEntitlement.expirationDate : nil
        return SubscriptionStatus(
            plan: plan,
            expiryDate: latestEntitlement.expirationDate,
            trialEndDate: trialEndDate
        )
    }

    func latestActiveEntitlement(monthlyProductID: String, yearlyProductID: String) async throws
        -> StoreKitEntitlementInfo?
    {
        let entitlements = try await entitlementsLoader()
        return Self.selectLatestActiveEntitlement(
            from: entitlements,
            monthlyProductID: monthlyProductID,
            yearlyProductID: yearlyProductID,
            now: dateProvider()
        )
    }

    static func selectLatestActiveEntitlement(
        from entitlements: [StoreKitEntitlementInfo],
        monthlyProductID: String,
        yearlyProductID: String,
        now: Date
    ) -> StoreKitEntitlementInfo? {
        var latestEntitlement: StoreKitEntitlementInfo?
        for entitlement in entitlements {
            guard entitlement.productID == monthlyProductID || entitlement.productID == yearlyProductID else {
                continue
            }
            if let revocationDate = entitlement.revocationDate, revocationDate <= now {
                continue
            }
            if let expirationDate = entitlement.expirationDate, expirationDate <= now {
                continue
            }

            guard let current = latestEntitlement else {
                latestEntitlement = entitlement
                continue
            }

            let currentExpiration = current.expirationDate ?? .distantFuture
            let candidateExpiration = entitlement.expirationDate ?? .distantFuture
            if candidateExpiration > currentExpiration {
                latestEntitlement = entitlement
            }
        }
        return latestEntitlement
    }
}
