import XCTest
@testable import EpisodeStocker

@MainActor
final class BackupSettingsViewModelTests: XCTestCase {
    func testFreePlanCannotEnableCloudSync() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1)),
            lastSyncAt: nil
        )
        let monitor = FakeCloudSyncStatusMonitor()
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: monitor,
            subscriptionStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        vm.setBackupEnabled(true)

        XCTAssertFalse(vm.isBackupEnabled)
        XCTAssertEqual(vm.errorMessage, "クラウド同期機能はサブスクリプション登録で利用できます。")
    }

    func testPremiumPlanCanEnableCloudSyncAndRequiresRestartNotice() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1)),
            lastSyncAt: nil
        )
        let monitor = FakeCloudSyncStatusMonitor()
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: monitor,
            subscriptionStatus: .init(plan: .yearly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        vm.setBackupEnabled(true)

        XCTAssertTrue(vm.isBackupEnabled)
        XCTAssertTrue(vm.requiresAppRestartNotice)
        XCTAssertNil(vm.errorMessage)
    }

    func testUnavailableCloudKitPreventsEnableToggle() async {
        let service = FakeCloudBackupService(
            availabilityValue: .unavailable(reason: "iCloud未ログイン"),
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1)),
            lastSyncAt: nil
        )
        let monitor = FakeCloudSyncStatusMonitor()
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: monitor,
            subscriptionStatus: .init(plan: .yearly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        vm.setBackupEnabled(true)

        XCTAssertFalse(vm.isBackupEnabled)
        XCTAssertEqual(vm.errorMessage, "iCloud未ログイン")
    }

    func testDowngradeDisablesCloudSyncAndRequiresRestartNotice() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: true,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1)),
            lastSyncAt: nil
        )
        let monitor = FakeCloudSyncStatusMonitor()
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: monitor,
            subscriptionStatus: .init(plan: .yearly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        vm.updateSubscriptionStatus(.init(plan: .free, expiryDate: nil, trialEndDate: nil))

        XCTAssertFalse(vm.isBackupEnabled)
        XCTAssertTrue(vm.requiresAppRestartNotice)
    }

    func testMonitorSnapshotUpdatesSyncStateAndLastSyncAt() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: true,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1)),
            lastSyncAt: nil
        )
        let monitor = FakeCloudSyncStatusMonitor()
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: monitor,
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()
        let expectedDate = Date(timeIntervalSince1970: 12345)

        monitor.send(.init(isSyncing: true, lastSyncAt: nil, lastErrorMessage: nil))
        XCTAssertTrue(vm.isSyncing)
        monitor.send(.init(isSyncing: false, lastSyncAt: expectedDate, lastErrorMessage: nil))

        XCTAssertFalse(vm.isSyncing)
        XCTAssertEqual(vm.lastSyncAt, expectedDate)
    }

    func testMonitorSnapshotClearsErrorWhenRecoverySnapshotArrives() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: true,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1)),
            lastSyncAt: nil
        )
        let monitor = FakeCloudSyncStatusMonitor()
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: monitor,
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        monitor.send(.init(isSyncing: false, lastSyncAt: nil, lastErrorMessage: "sync failed"))
        XCTAssertEqual(vm.errorMessage, "sync failed")
        monitor.send(.init(isSyncing: false, lastSyncAt: nil, lastErrorMessage: nil))

        XCTAssertNil(vm.errorMessage)
    }

    func testLoadAppliesDowngradePolicyForFreePlan() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: true,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1)),
            lastSyncAt: nil
        )
        let monitor = FakeCloudSyncStatusMonitor()
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: monitor,
            subscriptionStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
        )

        await vm.load()

        XCTAssertFalse(vm.isBackupEnabled)
        XCTAssertTrue(vm.requiresAppRestartNotice)
    }

    func testAvailabilityMessageForAvailableState() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1)),
            lastSyncAt: nil
        )
        let monitor = FakeCloudSyncStatusMonitor()
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: monitor
        )

        await vm.load()

        XCTAssertEqual(vm.availabilityMessage, "利用可能")
    }
}

private final class FakeCloudBackupService: CloudBackupService {
    private let availabilityValue: CloudBackupAvailability
    private var enabled: Bool
    private let manualBackupResult: Result<Date, Error>
    private var latestBackupAt: Date?

    init(
        availabilityValue: CloudBackupAvailability,
        enabled: Bool,
        manualBackupResult: Result<Date, Error>,
        lastSyncAt: Date?
    ) {
        self.availabilityValue = availabilityValue
        self.enabled = enabled
        self.manualBackupResult = manualBackupResult
        self.latestBackupAt = lastSyncAt
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

private final class FakeCloudSyncStatusMonitor: CloudSyncStatusMonitoring {
    var onChange: ((CloudSyncStatusSnapshot) -> Void)?
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func start() {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func send(_ snapshot: CloudSyncStatusSnapshot) {
        onChange?(snapshot)
    }
}
