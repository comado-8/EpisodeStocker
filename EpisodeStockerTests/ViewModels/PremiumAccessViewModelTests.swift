import XCTest
@testable import EpisodeStocker

@MainActor
final class PremiumAccessViewModelTests: XCTestCase {
    func testFreePlanHasNoPremiumAccess() {
        let vm = PremiumAccessViewModel(
            service: FakeSubscriptionServiceForPremiumAccess(
                status: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
            )
        )

        XCTAssertFalse(vm.hasPremiumAccess)
        XCTAssertFalse(vm.hasAccess(to: .analyticsTab))
        XCTAssertFalse(vm.hasAccess(to: .advancedSort))
    }

    func testTrialPlanHasPremiumAccessUntilTrialEnd() async {
        let now = Date(timeIntervalSince1970: 10_000)
        let vm = PremiumAccessViewModel(
            service: FakeSubscriptionServiceForPremiumAccess(
                status: .init(plan: .free, expiryDate: nil, trialEndDate: now.addingTimeInterval(2_000))
            ),
            now: { now }
        )
        await vm.refresh()

        XCTAssertTrue(vm.hasPremiumAccess)
        XCTAssertGreaterThan(vm.trialRemainingDays, 0)
    }

    func testCanCreateEpisodeAppliesFreeLimit() {
        let vm = PremiumAccessViewModel(
            service: FakeSubscriptionServiceForPremiumAccess(
                status: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
            )
        )

        XCTAssertTrue(vm.canCreateEpisode(currentActiveCount: PremiumAccessViewModel.freeEpisodeLimit - 1))
        XCTAssertFalse(vm.canCreateEpisode(currentActiveCount: PremiumAccessViewModel.freeEpisodeLimit))
    }

    func testPaidPlanCanCreateEpisodeBeyondFreeLimit() async {
        let vm = PremiumAccessViewModel(
            service: FakeSubscriptionServiceForPremiumAccess(
                status: .init(plan: .monthly, expiryDate: Date(), trialEndDate: nil)
            )
        )
        await vm.refresh()

        XCTAssertTrue(vm.canCreateEpisode(currentActiveCount: PremiumAccessViewModel.freeEpisodeLimit))
        XCTAssertTrue(vm.hasAccess(to: .backup))
    }

    func testEnsureStatusLoadedFetchesOnce() async {
        let service = FakeSubscriptionServiceForPremiumAccess(
            status: .init(plan: .yearly, expiryDate: Date(), trialEndDate: nil)
        )
        let vm = PremiumAccessViewModel(service: service)

        await vm.ensureStatusLoaded()
        await vm.ensureStatusLoaded()

        XCTAssertEqual(service.fetchStatusCallCount, 1)
        XCTAssertEqual(vm.subscriptionStatus.plan, .yearly)
    }

    func testRefreshCachesPremiumAccess() async {
        let entitlementCache = StubSubscriptionEntitlementCacheForPremiumAccess()
        let vm = PremiumAccessViewModel(
            service: FakeSubscriptionServiceForPremiumAccess(
                status: .init(plan: .monthly, expiryDate: Date(), trialEndDate: nil)
            ),
            cloudSyncPreferenceRepository: StubCloudSyncPreferenceRepositoryForPremiumAccess(),
            entitlementCache: entitlementCache
        )

        await vm.refresh()

        XCTAssertEqual(entitlementCache.premiumAccessCachedState(), .granted)
    }

    func testRefreshDisablesCloudSyncRequestWhenDowngradedToFree() async {
        let preference = StubCloudSyncPreferenceRepositoryForPremiumAccess()
        preference.setCloudSyncRequested(true)
        let vm = PremiumAccessViewModel(
            service: FakeSubscriptionServiceForPremiumAccess(
                status: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
            ),
            cloudSyncPreferenceRepository: preference,
            entitlementCache: StubSubscriptionEntitlementCacheForPremiumAccess()
        )

        await vm.refresh()

        XCTAssertFalse(preference.isCloudSyncRequested())
    }
}

private final class FakeSubscriptionServiceForPremiumAccess: SubscriptionService {
    private let status: SubscriptionStatus
    private(set) var fetchStatusCallCount = 0

    init(status: SubscriptionStatus) {
        self.status = status
    }

    func fetchStatus() async throws -> SubscriptionStatus {
        fetchStatusCallCount += 1
        return status
    }

    func fetchProducts() async throws -> [SubscriptionProduct] {
        []
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        .userCancelled
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        status
    }
}

private final class StubCloudSyncPreferenceRepositoryForPremiumAccess: CloudSyncPreferenceRepository {
    private var requested = false
    private var lastSyncDate: Date?

    func isCloudSyncRequested() -> Bool {
        requested
    }

    func setCloudSyncRequested(_ requested: Bool) {
        self.requested = requested
    }

    func lastSyncAt() -> Date? {
        lastSyncDate
    }

    func setLastSyncAt(_ date: Date?) {
        lastSyncDate = date
    }
}

private final class StubSubscriptionEntitlementCacheForPremiumAccess: SubscriptionEntitlementCaching {
    private var state: PremiumAccessCachedState = .unknown

    func premiumAccessCachedState() -> PremiumAccessCachedState {
        state
    }

    func setPremiumAccessCachedState(_ value: PremiumAccessCachedState) {
        state = value
    }
}
