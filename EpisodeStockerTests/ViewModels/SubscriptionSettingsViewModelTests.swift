import XCTest
@testable import EpisodeStocker

@MainActor
final class SubscriptionSettingsViewModelTests: XCTestCase {
    func testLoadReflectsStatusAndProducts() async {
        let service = FakeSubscriptionService(
            status: SubscriptionStatus(
                plan: .monthly,
                expiryDate: Date(timeIntervalSince1970: 10_000),
                trialEndDate: nil
            ),
            products: [
                SubscriptionProduct(
                    id: "com.episodestocker.premium.monthly",
                    displayName: "月額プラン",
                    displayPrice: "¥400",
                    plan: .monthly
                )
            ],
            purchaseOutcome: .userCancelled,
            restoredStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )
        let vm = SubscriptionSettingsViewModel(service: service)

        await vm.load()

        XCTAssertEqual(vm.status.plan, .monthly)
        XCTAssertEqual(vm.products.count, 1)
        XCTAssertEqual(vm.products.first?.id, "com.episodestocker.premium.monthly")
        XCTAssertNil(vm.errorMessage)
    }

    func testPurchaseUpdatesStatusOnSuccess() async {
        let purchased = SubscriptionStatus(plan: .yearly, expiryDate: Date(), trialEndDate: nil)
        let service = FakeSubscriptionService(
            status: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            products: [],
            purchaseOutcome: .purchased(purchased),
            restoredStatus: purchased
        )
        let vm = SubscriptionSettingsViewModel(service: service)

        await vm.purchase(productID: "com.episodestocker.premium.yearly")

        XCTAssertEqual(vm.status.plan, .yearly)
        XCTAssertNil(vm.errorMessage)
    }

    func testPurchaseCancelledSetsErrorMessage() async {
        let service = FakeSubscriptionService(
            status: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            products: [],
            purchaseOutcome: .userCancelled,
            restoredStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
        )
        let vm = SubscriptionSettingsViewModel(service: service)

        await vm.purchase(productID: "com.episodestocker.premium.monthly")

        XCTAssertEqual(vm.errorMessage, "購入はキャンセルされました。")
    }

    func testRestorePurchasesUpdatesStatus() async {
        let restored = SubscriptionStatus(plan: .monthly, expiryDate: Date(), trialEndDate: nil)
        let service = FakeSubscriptionService(
            status: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            products: [],
            purchaseOutcome: .pending,
            restoredStatus: restored
        )
        let vm = SubscriptionSettingsViewModel(service: service)

        await vm.restorePurchases()

        XCTAssertEqual(vm.status.plan, .monthly)
        XCTAssertNil(vm.errorMessage)
    }
}

private final class FakeSubscriptionService: SubscriptionService {
    private let status: SubscriptionStatus
    private let products: [SubscriptionProduct]
    private let purchaseOutcome: SubscriptionPurchaseOutcome
    private let restoredStatus: SubscriptionStatus

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
        _ = productID
        return purchaseOutcome
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        restoredStatus
    }
}
