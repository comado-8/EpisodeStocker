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
        XCTAssertFalse(repository.bool(for: .cloudBackupEnabled))

        repository.set(true, for: .cloudBackupEnabled)

        XCTAssertTrue(repository.bool(for: .cloudBackupEnabled))
    }

    func testDateRoundTripAndClear() {
        let expected = Date(timeIntervalSince1970: 1_234_567)
        repository.set(expected, for: .cloudBackupLastRunAt)

        XCTAssertEqual(repository.date(for: .cloudBackupLastRunAt), expected)

        repository.set(nil, for: .cloudBackupLastRunAt)
        XCTAssertNil(repository.date(for: .cloudBackupLastRunAt))
    }
}
