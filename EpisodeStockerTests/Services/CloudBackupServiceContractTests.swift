import XCTest
@testable import EpisodeStocker

@MainActor
final class CloudBackupServiceContractTests: XCTestCase {
    func testAvailabilityReturnsConfiguredValue() async {
        let service = StubCloudBackupService(
            availabilityValue: .available,
            initialEnabled: false,
            lastBackup: nil
        )

        let availability = await service.availability()

        XCTAssertEqual(availability, .available)
    }

    func testSetBackupEnabledPersistsState() throws {
        let service = StubCloudBackupService(
            availabilityValue: .available,
            initialEnabled: false,
            lastBackup: nil
        )

        try service.setBackupEnabled(true)

        XCTAssertTrue(service.isBackupEnabled())
    }

    func testRunManualBackupReturnsConfiguredDate() async throws {
        let date = Date(timeIntervalSince1970: 9_999)
        let service = StubCloudBackupService(
            availabilityValue: .available,
            initialEnabled: true,
            lastBackup: date
        )

        let actual = try await service.runManualBackup()

        XCTAssertEqual(actual, date)
    }
}

private final class StubCloudBackupService: CloudBackupService {
    private let availabilityValue: CloudBackupAvailability
    private var enabled: Bool
    private var lastBackup: Date?

    init(availabilityValue: CloudBackupAvailability, initialEnabled: Bool, lastBackup: Date?) {
        self.availabilityValue = availabilityValue
        self.enabled = initialEnabled
        self.lastBackup = lastBackup
    }

    func availability() async -> CloudBackupAvailability {
        availabilityValue
    }

    func isBackupEnabled() -> Bool {
        enabled
    }

    func setBackupEnabled(_ enabled: Bool) throws {
        self.enabled = enabled
    }

    func runManualBackup() async throws -> Date {
        let result = lastBackup ?? Date()
        lastBackup = result
        return result
    }

    func lastBackupAt() -> Date? {
        lastBackup
    }
}
