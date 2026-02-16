import XCTest
@testable import EpisodeStocker

@MainActor
final class StoreKitSubscriptionServiceTests: XCTestCase {
    func testFetchProductsMapsPlanAndSortsByConfiguredOrder() async throws {
        let client = FakeStoreKitClient(
            products: [
                StoreKitProductInfo(
                    id: SubscriptionCatalog.yearlyProductID,
                    displayName: "年額プラン",
                    displayPrice: "¥3,600"
                ),
                StoreKitProductInfo(
                    id: SubscriptionCatalog.monthlyProductID,
                    displayName: "月額プラン",
                    displayPrice: "¥400"
                )
            ],
            purchaseState: .userCancelled,
            status: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            statusError: nil
        )
        let service = StoreKitSubscriptionService(client: client)

        let products = try await service.fetchProducts()

        XCTAssertEqual(products.map(\.id), [SubscriptionCatalog.monthlyProductID, SubscriptionCatalog.yearlyProductID])
        XCTAssertEqual(products.map(\.plan), [.monthly, .yearly])
    }

    func testPurchasePurchasedReturnsLatestStatus() async throws {
        let expectedStatus = SubscriptionStatus(plan: .yearly, expiryDate: Date(), trialEndDate: nil)
        let client = FakeStoreKitClient(
            products: [],
            purchaseState: .purchased(productID: SubscriptionCatalog.yearlyProductID),
            status: expectedStatus,
            statusError: nil
        )
        let service = StoreKitSubscriptionService(client: client)

        let outcome = try await service.purchase(productID: SubscriptionCatalog.yearlyProductID)

        XCTAssertEqual(outcome, .purchased(expectedStatus))
        XCTAssertEqual(client.lastPurchasedProductID, SubscriptionCatalog.yearlyProductID)
    }

    func testPurchaseCancelledReturnsCancelledOutcome() async throws {
        let client = FakeStoreKitClient(
            products: [],
            purchaseState: .userCancelled,
            status: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            statusError: nil
        )
        let service = StoreKitSubscriptionService(client: client)

        let outcome = try await service.purchase(productID: SubscriptionCatalog.monthlyProductID)

        XCTAssertEqual(outcome, .userCancelled)
    }

    func testRestorePurchasesCallsSyncAndReturnsStatus() async throws {
        let expectedStatus = SubscriptionStatus(plan: .monthly, expiryDate: Date(), trialEndDate: nil)
        let client = FakeStoreKitClient(
            products: [],
            purchaseState: .pending,
            status: expectedStatus,
            statusError: nil
        )
        let service = StoreKitSubscriptionService(client: client)

        let restored = try await service.restorePurchases()

        XCTAssertEqual(restored, expectedStatus)
        XCTAssertTrue(client.didCallSync)
    }

    func testPurchasePurchasedReturnsFallbackWhenStatusFetchFails() async throws {
        let client = FakeStoreKitClient(
            products: [],
            purchaseState: .purchased(productID: SubscriptionCatalog.monthlyProductID),
            status: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            statusError: TestError.fetchFailed
        )
        let service = StoreKitSubscriptionService(client: client)

        let outcome = try await service.purchase(productID: SubscriptionCatalog.monthlyProductID)

        XCTAssertEqual(outcome, .purchasedStatusUnavailable(productID: SubscriptionCatalog.monthlyProductID))
    }
}

private final class FakeStoreKitClient: StoreKitClient {
    private let products: [StoreKitProductInfo]
    private let purchaseState: StoreKitPurchaseState
    private let status: SubscriptionStatus
    private let statusError: Error?
    private(set) var lastPurchasedProductID: String?
    private(set) var didCallSync = false

    init(
        products: [StoreKitProductInfo],
        purchaseState: StoreKitPurchaseState,
        status: SubscriptionStatus,
        statusError: Error?
    ) {
        self.products = products
        self.purchaseState = purchaseState
        self.status = status
        self.statusError = statusError
    }

    func fetchProducts(ids: [String]) async throws -> [StoreKitProductInfo] {
        products.filter { ids.contains($0.id) }
    }

    func purchase(productID: String) async throws -> StoreKitPurchaseState {
        lastPurchasedProductID = productID
        return purchaseState
    }

    func syncPurchases() async throws {
        didCallSync = true
    }

    func fetchActiveSubscriptionStatus(monthlyProductID: String, yearlyProductID: String) async throws
        -> SubscriptionStatus
    {
        _ = monthlyProductID
        _ = yearlyProductID
        if let statusError {
            throw statusError
        }
        return status
    }
}

private enum TestError: Error {
    case fetchFailed
}
