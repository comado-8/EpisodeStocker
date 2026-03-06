import XCTest
@testable import EpisodeStocker

final class CloudSyncModeResolverTests: XCTestCase {
    func testResolveReturnsTrueWhenRequestedAndPremiumCached() {
        let resolver = DefaultCloudSyncModeResolver(
            preferenceRepository: StubCloudSyncPreferenceRepository(
                isRequested: true,
                lastSyncAt: nil
            ),
            entitlementCache: StubSubscriptionEntitlementCache(state: .granted)
        )

        XCTAssertTrue(resolver.resolveEffectiveCloudSyncEnabled())
    }

    func testResolveReturnsFalseWhenRequestedButNotPremiumCached() {
        let resolver = DefaultCloudSyncModeResolver(
            preferenceRepository: StubCloudSyncPreferenceRepository(
                isRequested: true,
                lastSyncAt: nil
            ),
            entitlementCache: StubSubscriptionEntitlementCache(state: .denied)
        )

        XCTAssertFalse(resolver.resolveEffectiveCloudSyncEnabled())
    }

    func testResolveReturnsFalseWhenNotRequested() {
        let resolver = DefaultCloudSyncModeResolver(
            preferenceRepository: StubCloudSyncPreferenceRepository(
                isRequested: false,
                lastSyncAt: nil
            ),
            entitlementCache: StubSubscriptionEntitlementCache(state: .granted)
        )

        XCTAssertFalse(resolver.resolveEffectiveCloudSyncEnabled())
    }

    func testResolveReturnsFalseWhenRequestedButCacheUnknown() {
        let resolver = DefaultCloudSyncModeResolver(
            preferenceRepository: StubCloudSyncPreferenceRepository(
                isRequested: true,
                lastSyncAt: nil
            ),
            entitlementCache: StubSubscriptionEntitlementCache(state: .unknown)
        )

        XCTAssertFalse(resolver.resolveEffectiveCloudSyncEnabled())
    }
}

private final class StubCloudSyncPreferenceRepository: CloudSyncPreferenceRepository {
    private var isRequested: Bool
    private var syncDate: Date?

    init(isRequested: Bool, lastSyncAt: Date?) {
        self.isRequested = isRequested
        self.syncDate = lastSyncAt
    }

    func isCloudSyncRequested() -> Bool {
        isRequested
    }

    func setCloudSyncRequested(_ requested: Bool) {
        isRequested = requested
    }

    func lastSyncAt() -> Date? {
        syncDate
    }

    func setLastSyncAt(_ date: Date?) {
        syncDate = date
    }
}

private final class StubSubscriptionEntitlementCache: SubscriptionEntitlementCaching {
    private var state: PremiumAccessCachedState

    init(state: PremiumAccessCachedState) {
        self.state = state
    }

    func premiumAccessCachedState() -> PremiumAccessCachedState {
        state
    }

    func setPremiumAccessCachedState(_ value: PremiumAccessCachedState) {
        state = value
    }
}
