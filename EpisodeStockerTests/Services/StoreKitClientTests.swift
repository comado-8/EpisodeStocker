import XCTest
@testable import EpisodeStocker

final class StoreKitClientTests: XCTestCase {
    func testFetchProductsDelegatesToInjectedLoader() async throws {
        var capturedIDs: [String] = []
        let client = DefaultStoreKitClient(
            productsLoader: { ids in
                capturedIDs = ids
                return [StoreKitProductInfo(id: "p1", displayName: "Monthly", displayPrice: "¥400")]
            },
            purchaseHandler: { _ in .pending },
            syncHandler: {},
            entitlementsLoader: { [] },
            dateProvider: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let products = try await client.fetchProducts(ids: ["p1"])

        XCTAssertEqual(capturedIDs, ["p1"])
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?.id, "p1")
    }

    func testPurchaseDelegatesToInjectedHandler() async throws {
        var capturedProductID: String?
        let client = DefaultStoreKitClient(
            productsLoader: { _ in [] },
            purchaseHandler: { productID in
                capturedProductID = productID
                return .userCancelled
            },
            syncHandler: {},
            entitlementsLoader: { [] },
            dateProvider: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let result = try await client.purchase(productID: SubscriptionCatalog.monthlyProductID)

        XCTAssertEqual(result, .userCancelled)
        XCTAssertEqual(capturedProductID, SubscriptionCatalog.monthlyProductID)
    }

    func testSyncPurchasesDelegatesToInjectedHandler() async throws {
        var didCallSync = false
        let client = DefaultStoreKitClient(
            productsLoader: { _ in [] },
            purchaseHandler: { _ in .pending },
            syncHandler: { didCallSync = true },
            entitlementsLoader: { [] },
            dateProvider: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        try await client.syncPurchases()

        XCTAssertTrue(didCallSync)
    }

    func testFetchActiveSubscriptionStatusReturnsFreeWhenNoActiveEntitlement() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let client = DefaultStoreKitClient(
            productsLoader: { _ in [] },
            purchaseHandler: { _ in .pending },
            syncHandler: {},
            entitlementsLoader: {
                [
                    StoreKitEntitlementInfo(
                        productID: "com.example.other",
                        expirationDate: now.addingTimeInterval(3600),
                        revocationDate: nil,
                        offerType: nil
                    ),
                    StoreKitEntitlementInfo(
                        productID: SubscriptionCatalog.monthlyProductID,
                        expirationDate: now.addingTimeInterval(-1),
                        revocationDate: nil,
                        offerType: nil
                    ),
                ]
            },
            dateProvider: { now }
        )

        let status = try await client.fetchActiveSubscriptionStatus(
            monthlyProductID: SubscriptionCatalog.monthlyProductID,
            yearlyProductID: SubscriptionCatalog.yearlyProductID
        )

        XCTAssertEqual(status.plan, .free)
        XCTAssertNil(status.expiryDate)
        XCTAssertNil(status.trialEndDate)
    }

    func testFetchActiveSubscriptionStatusMapsIntroductoryTrial() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let expiry = now.addingTimeInterval(24 * 60 * 60)
        let client = DefaultStoreKitClient(
            productsLoader: { _ in [] },
            purchaseHandler: { _ in .pending },
            syncHandler: {},
            entitlementsLoader: {
                [
                    StoreKitEntitlementInfo(
                        productID: SubscriptionCatalog.monthlyProductID,
                        expirationDate: expiry,
                        revocationDate: nil,
                        offerType: .introductory
                    )
                ]
            },
            dateProvider: { now }
        )

        let status = try await client.fetchActiveSubscriptionStatus(
            monthlyProductID: SubscriptionCatalog.monthlyProductID,
            yearlyProductID: SubscriptionCatalog.yearlyProductID
        )

        XCTAssertEqual(status.plan, .monthly)
        XCTAssertEqual(status.expiryDate, expiry)
        XCTAssertEqual(status.trialEndDate, expiry)
    }

    func testFetchActiveSubscriptionStatusSelectsLatestValidEntitlement() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let monthlyExpiry = now.addingTimeInterval(2 * 24 * 60 * 60)
        let yearlyExpiry = now.addingTimeInterval(30 * 24 * 60 * 60)
        let client = DefaultStoreKitClient(
            productsLoader: { _ in [] },
            purchaseHandler: { _ in .pending },
            syncHandler: {},
            entitlementsLoader: {
                [
                    StoreKitEntitlementInfo(
                        productID: SubscriptionCatalog.monthlyProductID,
                        expirationDate: monthlyExpiry,
                        revocationDate: nil,
                        offerType: nil
                    ),
                    StoreKitEntitlementInfo(
                        productID: SubscriptionCatalog.yearlyProductID,
                        expirationDate: yearlyExpiry,
                        revocationDate: nil,
                        offerType: .promotional
                    ),
                    StoreKitEntitlementInfo(
                        productID: SubscriptionCatalog.yearlyProductID,
                        expirationDate: yearlyExpiry.addingTimeInterval(60),
                        revocationDate: now.addingTimeInterval(-1),
                        offerType: nil
                    ),
                ]
            },
            dateProvider: { now }
        )

        let status = try await client.fetchActiveSubscriptionStatus(
            monthlyProductID: SubscriptionCatalog.monthlyProductID,
            yearlyProductID: SubscriptionCatalog.yearlyProductID
        )

        XCTAssertEqual(status.plan, .yearly)
        XCTAssertEqual(status.expiryDate, yearlyExpiry)
        XCTAssertNil(status.trialEndDate)
    }

    func testSelectLatestActiveEntitlementTreatsNilExpirationAsDistantFuture() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let monthly = StoreKitEntitlementInfo(
            productID: SubscriptionCatalog.monthlyProductID,
            expirationDate: now.addingTimeInterval(24 * 60 * 60),
            revocationDate: nil,
            offerType: nil
        )
        let yearlyNoExpiration = StoreKitEntitlementInfo(
            productID: SubscriptionCatalog.yearlyProductID,
            expirationDate: nil,
            revocationDate: nil,
            offerType: nil
        )

        let selected = DefaultStoreKitClient.selectLatestActiveEntitlement(
            from: [monthly, yearlyNoExpiration],
            monthlyProductID: SubscriptionCatalog.monthlyProductID,
            yearlyProductID: SubscriptionCatalog.yearlyProductID,
            now: now
        )

        XCTAssertEqual(selected?.productID, SubscriptionCatalog.yearlyProductID)
        XCTAssertNil(selected?.expirationDate)
    }
}
