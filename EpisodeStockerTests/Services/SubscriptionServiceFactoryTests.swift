import XCTest
@testable import EpisodeStocker

@MainActor
final class SubscriptionServiceFactoryTests: XCTestCase {
    func testMakeServiceReturnsStoreKitWhenRevenueCatSDKUnavailable() {
        var configured = false
        let revenueCatService = MarkerSubscriptionService(marker: "revenuecat")
        let storeKitService = MarkerSubscriptionService(marker: "storekit")

        let service = SubscriptionServiceFactory.makeService(
            hasRevenueCatSDK: false,
            hasPublicAPIKey: true,
            configureRevenueCat: { configured = true },
            makeRevenueCatService: { revenueCatService },
            makeStoreKitService: { storeKitService }
        )

        XCTAssertFalse(configured)
        XCTAssertTrue(service as AnyObject === storeKitService)
    }

    func testMakeServiceReturnsStoreKitWhenPublicAPIKeyMissing() {
        var configured = false
        let revenueCatService = MarkerSubscriptionService(marker: "revenuecat")
        let storeKitService = MarkerSubscriptionService(marker: "storekit")

        let service = SubscriptionServiceFactory.makeService(
            hasRevenueCatSDK: true,
            hasPublicAPIKey: false,
            configureRevenueCat: { configured = true },
            makeRevenueCatService: { revenueCatService },
            makeStoreKitService: { storeKitService }
        )

        XCTAssertFalse(configured)
        XCTAssertTrue(service as AnyObject === storeKitService)
    }

    func testMakeServiceReturnsRevenueCatWhenSDKAndAPIKeyAvailable() {
        var configureCallCount = 0
        let revenueCatService = MarkerSubscriptionService(marker: "revenuecat")
        let storeKitService = MarkerSubscriptionService(marker: "storekit")

        let service = SubscriptionServiceFactory.makeService(
            hasRevenueCatSDK: true,
            hasPublicAPIKey: true,
            configureRevenueCat: { configureCallCount += 1 },
            makeRevenueCatService: { revenueCatService },
            makeStoreKitService: { storeKitService }
        )

        XCTAssertEqual(configureCallCount, 1)
        XCTAssertTrue(service as AnyObject === revenueCatService)
    }

    func testDefaultFactoryResolvesRuntimeConfiguration() {
        let service = SubscriptionServiceFactory.makeService()

        if RevenueCatConfig.hasPublicAPIKey {
            XCTAssertTrue(service is RevenueCatSubscriptionService)
        } else {
            XCTAssertTrue(service is StoreKitSubscriptionService)
        }
    }
}

private final class MarkerSubscriptionService: SubscriptionService {
    let marker: String

    init(marker: String) {
        self.marker = marker
    }

    func fetchStatus(forceRefresh _: Bool) async throws -> SubscriptionStatus {
        .init(plan: .free, expiryDate: nil, trialEndDate: nil)
    }

    func fetchProducts() async throws -> [SubscriptionProduct] {
        []
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        .userCancelled
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        .init(plan: .free, expiryDate: nil, trialEndDate: nil)
    }
}
