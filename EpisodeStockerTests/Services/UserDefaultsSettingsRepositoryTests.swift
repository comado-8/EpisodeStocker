import XCTest
@testable import EpisodeStocker

final class UserDefaultsSettingsRepositoryTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var repository: UserDefaultsSettingsRepository!

    override func setUp() {
        super.setUp()
        suiteName = "UserDefaultsSettingsRepositoryTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        repository = UserDefaultsSettingsRepository(userDefaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        repository = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testBoolRoundTrip() {
        XCTAssertFalse(repository.bool(for: .cloudSyncRequested))

        repository.set(true, for: .cloudSyncRequested)

        XCTAssertTrue(repository.bool(for: .cloudSyncRequested))
    }

    func testDateRoundTripAndClear() {
        let expected = Date(timeIntervalSince1970: 1_234_567)
        repository.set(expected, for: .cloudSyncLastSuccessAt)

        XCTAssertEqual(repository.date(for: .cloudSyncLastSuccessAt), expected)

        repository.set(nil, for: .cloudSyncLastSuccessAt)
        XCTAssertNil(repository.date(for: .cloudSyncLastSuccessAt))
    }

    func testPremiumCacheRoundTrip() {
        XCTAssertNil(repository.optionalBool(for: .hasPremiumAccessCached))

        repository.setOptionalBool(true, for: .hasPremiumAccessCached)
        XCTAssertEqual(repository.optionalBool(for: .hasPremiumAccessCached), true)

        repository.setOptionalBool(false, for: .hasPremiumAccessCached)
        XCTAssertEqual(repository.optionalBool(for: .hasPremiumAccessCached), false)

        repository.setOptionalBool(nil, for: .hasPremiumAccessCached)
        XCTAssertNil(repository.optionalBool(for: .hasPremiumAccessCached))
    }
}
