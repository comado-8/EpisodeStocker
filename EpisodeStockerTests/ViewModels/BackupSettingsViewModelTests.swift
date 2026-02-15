import XCTest
@testable import EpisodeStocker

@MainActor
final class BackupSettingsViewModelTests: XCTestCase {
    func testFreePlanCannotEnableBackup() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1))
        )
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            subscriptionStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        vm.setBackupEnabled(true)

        XCTAssertFalse(vm.isBackupEnabled)
        XCTAssertEqual(vm.errorMessage, "バックアップ機能はサブスクリプション登録で利用できます。")
    }

    func testPremiumPlanCanEnableBackup() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1))
        )
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            subscriptionStatus: .init(plan: .yearly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        vm.setBackupEnabled(true)

        XCTAssertTrue(vm.isBackupEnabled)
        XCTAssertNil(vm.errorMessage)
    }

    func testUnavailableCloudKitPreventsManualBackup() async {
        let service = FakeCloudBackupService(
            availabilityValue: .unavailable(reason: "iCloud未ログイン"),
            enabled: true,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1))
        )
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        await vm.runManualBackup()

        XCTAssertEqual(vm.errorMessage, "iCloud未ログイン")
    }

    func testManualBackupSuccessUpdatesLastBackupAt() async {
        let expectedDate = Date(timeIntervalSince1970: 12345)
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: true,
            manualBackupResult: .success(expectedDate)
        )
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        await vm.runManualBackup()

        XCTAssertEqual(vm.lastBackupAt, expectedDate)
        XCTAssertNil(vm.errorMessage)
    }
}

private final class FakeCloudBackupService: CloudBackupService {
    private let availabilityValue: CloudBackupAvailability
    private var enabled: Bool
    private let manualBackupResult: Result<Date, Error>
    private var latestBackupAt: Date?

    init(availabilityValue: CloudBackupAvailability, enabled: Bool, manualBackupResult: Result<Date, Error>) {
        self.availabilityValue = availabilityValue
        self.enabled = enabled
        self.manualBackupResult = manualBackupResult
        self.latestBackupAt = nil
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
        let result = try manualBackupResult.get()
        latestBackupAt = result
        return result
    }

    func lastBackupAt() -> Date? {
        latestBackupAt
    }
}
