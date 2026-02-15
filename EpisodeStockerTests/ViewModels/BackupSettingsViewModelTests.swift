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

    func testUnavailableCloudKitPreventsEnableToggle() async {
        let service = FakeCloudBackupService(
            availabilityValue: .unavailable(reason: "iCloud未ログイン"),
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1))
        )
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            subscriptionStatus: .init(plan: .yearly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        vm.setBackupEnabled(true)

        XCTAssertFalse(vm.isBackupEnabled)
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

    func testDisableBackupClearsErrorAndTurnsOffFlag() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: true,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1))
        )
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()
        vm.setBackupEnabled(true)

        vm.setBackupEnabled(false)

        XCTAssertFalse(vm.isBackupEnabled)
        XCTAssertNil(vm.errorMessage)
    }

    func testRunManualBackupWithFreePlanSetsNotEntitledError() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: true,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1))
        )
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            subscriptionStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        await vm.runManualBackup()

        XCTAssertEqual(vm.errorMessage, "バックアップ機能はサブスクリプション登録で利用できます。")
    }

    func testRunManualBackupWhenDisabledSetsBackupDisabledError() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1))
        )
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        await vm.runManualBackup()

        XCTAssertEqual(vm.errorMessage, "クラウドバックアップを有効にしてください。")
    }

    func testUpdateSubscriptionStatusEnablesTrialAccess() {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1))
        )
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            subscriptionStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
        )

        XCTAssertFalse(vm.canUseBackup)
        vm.updateSubscriptionStatus(
            .init(plan: .free, expiryDate: nil, trialEndDate: Date().addingTimeInterval(10_000))
        )
        XCTAssertTrue(vm.canUseBackup)
    }

    func testAvailabilityMessageForAvailableState() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1))
        )
        let vm = BackupSettingsViewModel(cloudBackupService: service)

        await vm.load()

        XCTAssertEqual(vm.availabilityMessage, "利用可能")
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
