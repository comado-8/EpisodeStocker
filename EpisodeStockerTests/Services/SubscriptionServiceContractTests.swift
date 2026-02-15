import XCTest
@testable import EpisodeStocker

@MainActor
final class SubscriptionServiceContractTests: XCTestCase {
    func testFetchStatusReturnsConfiguredStatus() async throws {
        let expected = SubscriptionStatus(
            plan: .monthly,
            expiryDate: Date(timeIntervalSince1970: 1234),
            trialEndDate: nil
        )
        let service = StubSubscriptionService(
            status: expected,
            products: [],
            purchaseOutcome: .userCancelled,
            restoredStatus: expected
        )

        let actual = try await service.fetchStatus()

        XCTAssertEqual(actual, expected)
    }

    func testFetchProductsReturnsConfiguredProducts() async throws {
        let expected = [
            SubscriptionProduct(
                id: "monthly",
                displayName: "月額",
                displayPrice: "¥400",
                plan: .monthly
            ),
            SubscriptionProduct(
                id: "yearly",
                displayName: "年額",
                displayPrice: "¥3,600",
                plan: .yearly
            )
        ]
        let free = SubscriptionStatus(plan: .free, expiryDate: nil, trialEndDate: nil)
        let service = StubSubscriptionService(
            status: free,
            products: expected,
            purchaseOutcome: .userCancelled,
            restoredStatus: free
        )

        let actual = try await service.fetchProducts()

        XCTAssertEqual(actual, expected)
    }

    func testPurchaseReturnsConfiguredOutcomeAndCapturesProductID() async throws {
        let expectedStatus = SubscriptionStatus(plan: .yearly, expiryDate: Date(), trialEndDate: nil)
        let service = StubSubscriptionService(
            status: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            products: [],
            purchaseOutcome: .purchased(expectedStatus),
            restoredStatus: expectedStatus
        )

        let outcome = try await service.purchase(productID: "com.episodestocker.premium.yearly")

        XCTAssertEqual(service.capturedPurchaseProductID, "com.episodestocker.premium.yearly")
        XCTAssertEqual(outcome, .purchased(expectedStatus))
    }

    func testRestorePurchasesReturnsConfiguredStatus() async throws {
        let expected = SubscriptionStatus(plan: .monthly, expiryDate: Date(), trialEndDate: nil)
        let service = StubSubscriptionService(
            status: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            products: [],
            purchaseOutcome: .userCancelled,
            restoredStatus: expected
        )

        let actual = try await service.restorePurchases()

        XCTAssertEqual(actual, expected)
    }
}

private final class StubSubscriptionService: SubscriptionService {
    private let status: SubscriptionStatus
    private let products: [SubscriptionProduct]
    private let purchaseOutcome: SubscriptionPurchaseOutcome
    private let restoredStatus: SubscriptionStatus

    private(set) var capturedPurchaseProductID: String?

    init(
        status: SubscriptionStatus,
        products: [SubscriptionProduct],
        purchaseOutcome: SubscriptionPurchaseOutcome,
        restoredStatus: SubscriptionStatus
    ) {
        self.status = status
        self.products = products
        self.purchaseOutcome = purchaseOutcome
        self.restoredStatus = restoredStatus
    }

    func fetchStatus() async throws -> SubscriptionStatus {
        status
    }

    func fetchProducts() async throws -> [SubscriptionProduct] {
        products
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        capturedPurchaseProductID = productID
        return purchaseOutcome
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        restoredStatus
    }
}
