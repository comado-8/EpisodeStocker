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
            restoredStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil),
            fetchStatusError: nil,
            fetchProductsError: nil,
            purchaseError: nil,
            restoreError: nil
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
            restoredStatus: purchased,
            fetchStatusError: nil,
            fetchProductsError: nil,
            purchaseError: nil,
            restoreError: nil
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
            restoredStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            fetchStatusError: nil,
            fetchProductsError: nil,
            purchaseError: nil,
            restoreError: nil
        )
        let vm = SubscriptionSettingsViewModel(service: service)

        await vm.purchase(productID: "com.episodestocker.premium.monthly")

        XCTAssertEqual(vm.errorMessage, "購入はキャンセルされました。")
    }

    func testPurchaseStatusUnavailableSetsInformativeMessage() async {
        let service = FakeSubscriptionService(
            status: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            products: [],
            purchaseOutcome: .purchasedStatusUnavailable(productID: SubscriptionCatalog.monthlyProductID),
            restoredStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            fetchStatusError: nil,
            fetchProductsError: nil,
            purchaseError: nil,
            restoreError: nil
        )
        let vm = SubscriptionSettingsViewModel(service: service)

        await vm.purchase(productID: SubscriptionCatalog.monthlyProductID)

        XCTAssertEqual(vm.status.plan, .free)
        XCTAssertEqual(
            vm.errorMessage,
            "購入は完了しましたが、最新状態の取得に失敗しました。(商品ID: \(SubscriptionCatalog.monthlyProductID))"
        )
    }

    func testRestorePurchasesUpdatesStatus() async {
        let restored = SubscriptionStatus(plan: .monthly, expiryDate: Date(), trialEndDate: nil)
        let service = FakeSubscriptionService(
            status: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            products: [],
            purchaseOutcome: .pending,
            restoredStatus: restored,
            fetchStatusError: nil,
            fetchProductsError: nil,
            purchaseError: nil,
            restoreError: nil
        )
        let vm = SubscriptionSettingsViewModel(service: service)

        await vm.restorePurchases()

        XCTAssertEqual(vm.status.plan, .monthly)
        XCTAssertNil(vm.errorMessage)
    }

    func testPurchasePendingSetsErrorMessage() async {
        let service = FakeSubscriptionService(
            status: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            products: [],
            purchaseOutcome: .pending,
            restoredStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            fetchStatusError: nil,
            fetchProductsError: nil,
            purchaseError: nil,
            restoreError: nil
        )
        let vm = SubscriptionSettingsViewModel(service: service)

        await vm.purchase(productID: SubscriptionCatalog.monthlyProductID)

        XCTAssertEqual(vm.errorMessage, "購入は保留中です。")
    }

    func testLoadFailureSetsErrorMessage() async {
        let service = FakeSubscriptionService(
            status: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            products: [],
            purchaseOutcome: .pending,
            restoredStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            fetchStatusError: TestServiceError.failed("status error"),
            fetchProductsError: nil,
            purchaseError: nil,
            restoreError: nil
        )
        let vm = SubscriptionSettingsViewModel(service: service)

        await vm.load()

        XCTAssertEqual(vm.errorMessage, "status error")
        XCTAssertFalse(vm.isLoading)
    }

    func testLoadFailureDoesNotPartiallyUpdateState() async {
        let initialProducts = [
            SubscriptionProduct(
                id: SubscriptionCatalog.monthlyProductID,
                displayName: "初期",
                displayPrice: "¥0",
                plan: .monthly
            )
        ]
        let service = FakeSubscriptionService(
            status: .init(plan: .yearly, expiryDate: Date(), trialEndDate: nil),
            products: [
                SubscriptionProduct(
                    id: SubscriptionCatalog.yearlyProductID,
                    displayName: "年額",
                    displayPrice: "¥3,600",
                    plan: .yearly
                )
            ],
            purchaseOutcome: .pending,
            restoredStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            fetchStatusError: nil,
            fetchProductsError: TestServiceError.failed("products error"),
            purchaseError: nil,
            restoreError: nil
        )
        let vm = SubscriptionSettingsViewModel(
            service: service,
            initialStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            initialProducts: initialProducts
        )

        await vm.load()

        XCTAssertEqual(vm.status.plan, .free)
        XCTAssertEqual(vm.products, initialProducts)
        XCTAssertEqual(vm.errorMessage, "products error")
    }

    func testTrialRemainingDaysAndHasPremiumAccess() {
        let now = Date()
        let service = FakeSubscriptionService(
            status: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            products: [],
            purchaseOutcome: .pending,
            restoredStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            fetchStatusError: nil,
            fetchProductsError: nil,
            purchaseError: nil,
            restoreError: nil
        )
        let vm = SubscriptionSettingsViewModel(
            service: service,
            initialStatus: .init(plan: .free, expiryDate: nil, trialEndDate: now.addingTimeInterval(26 * 60 * 60))
        )

        XCTAssertGreaterThanOrEqual(vm.trialRemainingDays, 1)
        XCTAssertTrue(vm.hasPremiumAccess)
    }

    func testFreeWithoutTrialHasNoPremiumAccess() {
        let service = FakeSubscriptionService(
            status: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            products: [],
            purchaseOutcome: .pending,
            restoredStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil),
            fetchStatusError: nil,
            fetchProductsError: nil,
            purchaseError: nil,
            restoreError: nil
        )
        let vm = SubscriptionSettingsViewModel(service: service)

        XCTAssertEqual(vm.trialRemainingDays, 0)
        XCTAssertFalse(vm.hasPremiumAccess)
    }
}

private final class FakeSubscriptionService: SubscriptionService {
    private let status: SubscriptionStatus
    private let products: [SubscriptionProduct]
    private let purchaseOutcome: SubscriptionPurchaseOutcome
    private let restoredStatus: SubscriptionStatus
    private let fetchStatusError: Error?
    private let fetchProductsError: Error?
    private let purchaseError: Error?
    private let restoreError: Error?

    init(
        status: SubscriptionStatus,
        products: [SubscriptionProduct],
        purchaseOutcome: SubscriptionPurchaseOutcome,
        restoredStatus: SubscriptionStatus,
        fetchStatusError: Error? = nil,
        fetchProductsError: Error? = nil,
        purchaseError: Error? = nil,
        restoreError: Error? = nil
    ) {
        self.status = status
        self.products = products
        self.purchaseOutcome = purchaseOutcome
        self.restoredStatus = restoredStatus
        self.fetchStatusError = fetchStatusError
        self.fetchProductsError = fetchProductsError
        self.purchaseError = purchaseError
        self.restoreError = restoreError
    }

    func fetchStatus() async throws -> SubscriptionStatus {
        if let fetchStatusError {
            throw fetchStatusError
        }
        return status
    }

    func fetchProducts() async throws -> [SubscriptionProduct] {
        if let fetchProductsError {
            throw fetchProductsError
        }
        return products
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        if let purchaseError {
            throw purchaseError
        }
        _ = productID
        return purchaseOutcome
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        if let restoreError {
            throw restoreError
        }
        return restoredStatus
    }
}

private enum TestServiceError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            return message
        }
    }
}
