import XCTest
@testable import EpisodeStocker

@MainActor
final class PremiumAccessViewModelTests: XCTestCase {
    private struct DummyError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

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

    func testTrialRemainingDaysIsZeroWhenNoTrial() {
        let vm = PremiumAccessViewModel(
            service: FakeSubscriptionServiceForPremiumAccess(
                status: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
            )
        )

        XCTAssertEqual(vm.trialRemainingDays, 0)
    }

    func testTrialRemainingDaysIsZeroWhenExpired() async {
        let now = Date(timeIntervalSince1970: 10_000)
        let vm = PremiumAccessViewModel(
            service: FakeSubscriptionServiceForPremiumAccess(
                status: .init(plan: .free, expiryDate: nil, trialEndDate: now.addingTimeInterval(-10))
            ),
            now: { now }
        )
        await vm.refresh()

        XCTAssertEqual(vm.trialRemainingDays, 0)
        XCTAssertFalse(vm.hasPremiumAccess)
    }

    func testRefreshCachesDeniedForFreePlan() async {
        let entitlementCache = StubSubscriptionEntitlementCacheForPremiumAccess()
        let vm = PremiumAccessViewModel(
            service: FakeSubscriptionServiceForPremiumAccess(
                status: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
            ),
            cloudSyncPreferenceRepository: StubCloudSyncPreferenceRepositoryForPremiumAccess(),
            entitlementCache: entitlementCache
        )

        await vm.refresh()

        XCTAssertEqual(entitlementCache.premiumAccessCachedState(), .denied)
    }

    func testRefreshFailureSetsErrorAndDoesNotSetLoaded() async {
        let vm = PremiumAccessViewModel(
            service: FakeSequenceSubscriptionService(
                results: [.failure(DummyError(message: "network error"))]
            ),
            cloudSyncPreferenceRepository: StubCloudSyncPreferenceRepositoryForPremiumAccess(),
            entitlementCache: StubSubscriptionEntitlementCacheForPremiumAccess()
        )

        await vm.refresh()

        XCTAssertEqual(vm.lastErrorMessage, "network error")
        XCTAssertFalse(vm.hasLoadedStatus)
    }

    func testEnsureStatusLoadedRetriesAfterFailure() async {
        let service = FakeSequenceSubscriptionService(
            results: [
                .failure(DummyError(message: "first failed")),
                .success(.init(plan: .monthly, expiryDate: Date(), trialEndDate: nil))
            ]
        )
        let vm = PremiumAccessViewModel(
            service: service,
            cloudSyncPreferenceRepository: StubCloudSyncPreferenceRepositoryForPremiumAccess(),
            entitlementCache: StubSubscriptionEntitlementCacheForPremiumAccess()
        )

        await vm.ensureStatusLoaded()
        await vm.ensureStatusLoaded()

        XCTAssertEqual(service.fetchStatusCallCount, 2)
        XCTAssertTrue(vm.hasLoadedStatus)
        XCTAssertEqual(vm.subscriptionStatus.plan, .monthly)
        XCTAssertNil(vm.lastErrorMessage)
    }

    func testConcurrentRefreshCallsOnlyFetchOnceWhileInFlight() async {
        let service = FakeDelayedSubscriptionService(
            status: .init(plan: .yearly, expiryDate: Date(), trialEndDate: nil),
            delayNanoseconds: 200_000_000
        )
        let vm = PremiumAccessViewModel(
            service: service,
            cloudSyncPreferenceRepository: StubCloudSyncPreferenceRepositoryForPremiumAccess(),
            entitlementCache: StubSubscriptionEntitlementCacheForPremiumAccess()
        )

        async let first: Void = vm.refresh()
        async let second: Void = vm.refresh()
        _ = await (first, second)

        XCTAssertEqual(service.fetchStatusCallCount, 1)
        XCTAssertTrue(vm.hasLoadedStatus)
    }

    func testRefreshDoesNotToggleCloudSyncWhenAlreadyOff() async {
        let preference = StubCloudSyncPreferenceRepositoryForPremiumAccess()
        let vm = PremiumAccessViewModel(
            service: FakeSubscriptionServiceForPremiumAccess(
                status: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
            ),
            cloudSyncPreferenceRepository: preference,
            entitlementCache: StubSubscriptionEntitlementCacheForPremiumAccess()
        )

        await vm.refresh()

        XCTAssertEqual(preference.setCloudSyncRequestedCallCount, 0)
        XCTAssertFalse(preference.isCloudSyncRequested())
    }

    func testPaywallTriggerMetadataMapping() {
        let triggers: [PaywallTrigger] = [
            .analyticsTab,
            .advancedSort,
            .advancedSearch,
            .export,
            .backup,
            .episodeQuotaOver50
        ]

        let expectedFeatures: [PaywallTrigger: PremiumFeature] = [
            .analyticsTab: .analyticsTab,
            .advancedSort: .advancedSort,
            .advancedSearch: .advancedSearch,
            .export: .export,
            .backup: .backup,
            .episodeQuotaOver50: .episodeQuotaOver50
        ]

        for trigger in triggers {
            XCTAssertEqual(trigger.id, trigger.rawValue)
            XCTAssertFalse(trigger.title.isEmpty)
            XCTAssertFalse(trigger.message.isEmpty)
            XCTAssertEqual(trigger.feature, expectedFeatures[trigger])
        }
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
    private(set) var setCloudSyncRequestedCallCount = 0

    func isCloudSyncRequested() -> Bool {
        requested
    }

    func setCloudSyncRequested(_ requested: Bool) {
        setCloudSyncRequestedCallCount += 1
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

private final class FakeSequenceSubscriptionService: SubscriptionService {
    private var results: [Result<SubscriptionStatus, Error>]
    private(set) var fetchStatusCallCount = 0

    init(results: [Result<SubscriptionStatus, Error>]) {
        self.results = results
    }

    func fetchStatus() async throws -> SubscriptionStatus {
        fetchStatusCallCount += 1
        guard !results.isEmpty else {
            throw NSError(domain: "FakeSequenceSubscriptionService", code: 1)
        }
        let next = results.removeFirst()
        return try next.get()
    }

    func fetchProducts() async throws -> [SubscriptionProduct] {
        []
    }

    func purchase(productID _: String) async throws -> SubscriptionPurchaseOutcome {
        .userCancelled
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        .init(plan: .free, expiryDate: nil, trialEndDate: nil)
    }
}

private final class FakeDelayedSubscriptionService: SubscriptionService {
    let status: SubscriptionStatus
    let delayNanoseconds: UInt64
    private(set) var fetchStatusCallCount = 0

    init(status: SubscriptionStatus, delayNanoseconds: UInt64) {
        self.status = status
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchStatus() async throws -> SubscriptionStatus {
        fetchStatusCallCount += 1
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return status
    }

    func fetchProducts() async throws -> [SubscriptionProduct] {
        []
    }

    func purchase(productID _: String) async throws -> SubscriptionPurchaseOutcome {
        .userCancelled
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        status
    }
}
