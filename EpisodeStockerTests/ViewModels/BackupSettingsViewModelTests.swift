import XCTest
@testable import EpisodeStocker

@MainActor
final class BackupSettingsViewModelTests: XCTestCase {
    private struct DummyError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    func testFreePlanCannotEnableCloudSync() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1)),
            lastBackupAt: nil
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
            lastBackupAt: nil
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
            lastBackupAt: nil
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
            lastBackupAt: nil
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
            lastBackupAt: nil
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
            lastBackupAt: nil
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

    func testLoadDoesNotApplyDowngradePolicyBeforeSubscriptionStatusResolution() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: true,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1)),
            lastBackupAt: nil
        )
        let monitor = FakeCloudSyncStatusMonitor()
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: monitor,
            subscriptionStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
        )

        await vm.load()

        XCTAssertTrue(vm.isBackupEnabled)
        XCTAssertFalse(vm.requiresAppRestartNotice)
        XCTAssertEqual(monitor.startCallCount, 1)
    }

    func testLoadInitialStateResolvesInitialLoadingOnSuccessfulFetch() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1)),
            lastBackupAt: nil
        )
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor(),
            subscriptionStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
        )

        await vm.loadInitialState(
            using: FakeSubscriptionServiceForBackupSettings(
                fetchStatusResult: .success(.init(plan: .monthly, expiryDate: nil, trialEndDate: nil))
            )
        )

        XCTAssertFalse(vm.isInitialSubscriptionResolving)
        XCTAssertFalse(vm.isInitialLoadingOverlayVisible)
        XCTAssertFalse(vm.isSyncInteractionDisabled)
    }

    func testLoadInitialStateHidesOverlayAfterTimeoutAndKeepsControlsDisabledWhenUnresolved() async {
        let vm = BackupSettingsViewModel(
            cloudBackupService: FakeCloudBackupService(
                availabilityValue: .available,
                enabled: false,
                manualBackupResult: .success(Date()),
                lastBackupAt: nil
            ),
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor(),
            initialLoadingOverlayTimeout: .milliseconds(10),
            subscriptionStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
        )

        await vm.loadInitialState(
            using: FakeSubscriptionServiceForBackupSettings(
                fetchStatusResult: .failure(DummyError(message: "fetch failed"))
            )
        )
        try? await Task.sleep(for: .milliseconds(40))

        XCTAssertTrue(vm.isInitialSubscriptionResolving)
        XCTAssertFalse(vm.isInitialLoadingOverlayVisible)
        XCTAssertTrue(vm.isSyncInteractionDisabled)
        XCTAssertEqual(vm.errorMessage, "fetch failed")
    }

    func testDeinitStopsCloudSyncStatusMonitor() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1)),
            lastBackupAt: nil
        )
        let monitor = FakeCloudSyncStatusMonitor()
        var vm: BackupSettingsViewModel? = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: monitor,
            subscriptionStatus: .init(plan: .yearly, expiryDate: nil, trialEndDate: nil)
        )
        weak var weakVM = vm

        await vm?.load()
        XCTAssertEqual(monitor.startCallCount, 1)

        vm = nil

        XCTAssertNil(weakVM)
        XCTAssertEqual(monitor.stopCallCount, 1)
    }

    func testAvailabilityMessageForAvailableState() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1)),
            lastBackupAt: nil
        )
        let monitor = FakeCloudSyncStatusMonitor()
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: monitor
        )

        await vm.load()

        XCTAssertEqual(vm.availabilityMessage, "利用可能")
    }

    func testAvailabilityMessageForUnavailableState() async {
        let service = FakeCloudBackupService(
            availabilityValue: .unavailable(reason: "iCloud未ログイン"),
            enabled: false,
            manualBackupResult: .success(Date(timeIntervalSince1970: 1)),
            lastBackupAt: nil
        )
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor()
        )

        await vm.load()

        XCTAssertEqual(vm.availabilityMessage, "iCloud未ログイン")
    }

    func testCanUseBackupAllowsFreeTrial() {
        let vm = BackupSettingsViewModel(
            cloudBackupService: FakeCloudBackupService(
                availabilityValue: .available,
                enabled: false,
                manualBackupResult: .success(Date()),
                lastBackupAt: nil
            ),
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor(),
            subscriptionStatus: .init(
                plan: .free,
                expiryDate: nil,
                trialEndDate: Date().addingTimeInterval(3600)
            )
        )

        XCTAssertTrue(vm.canUseBackup)
    }

    func testCanUseBackupBypassesEntitlementWhenDisabled() {
        let vm = BackupSettingsViewModel(
            cloudBackupService: FakeCloudBackupService(
                availabilityValue: .available,
                enabled: false,
                manualBackupResult: .success(Date()),
                lastBackupAt: nil
            ),
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor(),
            isEntitlementCheckEnabled: false,
            subscriptionStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
        )

        XCTAssertTrue(vm.canUseBackup)
    }

    func testRefreshSubscriptionStatusSuccessUpdatesStatusAndDowngradesEnabledState() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: true,
            manualBackupResult: .success(Date()),
            lastBackupAt: nil
        )
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor(),
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )

        await vm.refreshSubscriptionStatus(
            using: FakeSubscriptionServiceForBackupSettings(
                fetchStatusResult: .success(.init(plan: .free, expiryDate: nil, trialEndDate: nil))
            )
        )

        XCTAssertEqual(vm.subscriptionStatus.plan, .free)
        XCTAssertFalse(vm.isBackupEnabled)
        XCTAssertTrue(vm.requiresAppRestartNotice)
    }

    func testRefreshSubscriptionStatusFailureSetsErrorMessage() async {
        let vm = BackupSettingsViewModel(
            cloudBackupService: FakeCloudBackupService(
                availabilityValue: .available,
                enabled: false,
                manualBackupResult: .success(Date()),
                lastBackupAt: nil
            ),
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor(),
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )

        await vm.refreshSubscriptionStatus(
            using: FakeSubscriptionServiceForBackupSettings(
                fetchStatusResult: .failure(DummyError(message: "fetch failed"))
            )
        )

        XCTAssertEqual(vm.errorMessage, "fetch failed")
    }

    func testSetBackupEnabledFalseFailureSetsErrorMessage() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: true,
            manualBackupResult: .success(Date()),
            lastBackupAt: nil
        )
        service.setBackupEnabledErrorForValue[false] = DummyError(message: "toggle off failed")
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor(),
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        vm.setBackupEnabled(false)

        XCTAssertEqual(vm.errorMessage, "toggle off failed")
        XCTAssertTrue(vm.isBackupEnabled)
    }

    func testSetBackupEnabledTrueFailureSetsErrorMessage() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: false,
            manualBackupResult: .success(Date()),
            lastBackupAt: nil
        )
        service.setBackupEnabledErrorForValue[true] = DummyError(message: "toggle on failed")
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor(),
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        vm.setBackupEnabled(true)

        XCTAssertEqual(vm.errorMessage, "toggle on failed")
        XCTAssertFalse(vm.isBackupEnabled)
    }

    func testRunManualBackupWhenDisabledShowsBackupDisabledError() async {
        let vm = BackupSettingsViewModel(
            cloudBackupService: FakeCloudBackupService(
                availabilityValue: .available,
                enabled: false,
                manualBackupResult: .success(Date()),
                lastBackupAt: nil
            ),
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor(),
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        await vm.runManualBackup()

        XCTAssertEqual(vm.errorMessage, CloudBackupError.backupDisabled.localizedDescription)
        XCTAssertFalse(vm.isRunningBackup)
    }

    func testRunManualBackupWhenNotEntitledShowsError() async {
        let vm = BackupSettingsViewModel(
            cloudBackupService: FakeCloudBackupService(
                availabilityValue: .available,
                enabled: true,
                manualBackupResult: .success(Date()),
                lastBackupAt: nil
            ),
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor(),
            subscriptionStatus: .init(plan: .free, expiryDate: nil, trialEndDate: nil)
        )

        await vm.runManualBackup()

        XCTAssertEqual(vm.errorMessage, CloudBackupError.notEntitled.localizedDescription)
        XCTAssertFalse(vm.isRunningBackup)
    }

    func testRunManualBackupWhenUnavailableShowsReason() async {
        let vm = BackupSettingsViewModel(
            cloudBackupService: FakeCloudBackupService(
                availabilityValue: .unavailable(reason: "iCloud未ログイン"),
                enabled: true,
                manualBackupResult: .success(Date()),
                lastBackupAt: nil
            ),
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor(),
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        await vm.runManualBackup()

        XCTAssertEqual(vm.errorMessage, "iCloud未ログイン")
        XCTAssertFalse(vm.isRunningBackup)
    }

    func testRunManualBackupSuccessUpdatesLastBackupDateAndClearsError() async {
        let expected = Date(timeIntervalSince1970: 777)
        let vm = BackupSettingsViewModel(
            cloudBackupService: FakeCloudBackupService(
                availabilityValue: .available,
                enabled: true,
                manualBackupResult: .success(expected),
                lastBackupAt: nil
            ),
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor(),
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()
        vm.errorMessage = "old error"

        await vm.runManualBackup()

        XCTAssertEqual(vm.lastBackupAt, expected)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isRunningBackup)
    }

    func testRunManualBackupFailureSetsErrorAndResetsRunningState() async {
        let vm = BackupSettingsViewModel(
            cloudBackupService: FakeCloudBackupService(
                availabilityValue: .available,
                enabled: true,
                manualBackupResult: .failure(DummyError(message: "backup failed")),
                lastBackupAt: nil
            ),
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor(),
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        await vm.runManualBackup()

        XCTAssertEqual(vm.errorMessage, "backup failed")
        XCTAssertFalse(vm.isRunningBackup)
    }

    func testDowngradePolicyFailureKeepsEnabledAndSetsError() async {
        let service = FakeCloudBackupService(
            availabilityValue: .available,
            enabled: true,
            manualBackupResult: .success(Date()),
            lastBackupAt: nil
        )
        service.setBackupEnabledErrorForValue[false] = DummyError(message: "downgrade failed")
        let vm = BackupSettingsViewModel(
            cloudBackupService: service,
            cloudSyncStatusMonitor: FakeCloudSyncStatusMonitor(),
            subscriptionStatus: .init(plan: .monthly, expiryDate: nil, trialEndDate: nil)
        )
        await vm.load()

        vm.updateSubscriptionStatus(.init(plan: .free, expiryDate: nil, trialEndDate: nil))

        XCTAssertTrue(vm.isBackupEnabled)
        XCTAssertEqual(vm.errorMessage, "downgrade failed")
    }
}

private final class FakeCloudBackupService: CloudBackupService {
    private let availabilityValue: CloudBackupAvailability
    private var enabled: Bool
    private let manualBackupResult: Result<Date, Error>
    private var latestBackupAt: Date?
    var setBackupEnabledErrorForValue: [Bool: Error] = [:]

    init(
        availabilityValue: CloudBackupAvailability,
        enabled: Bool,
        manualBackupResult: Result<Date, Error>,
        lastBackupAt: Date?
    ) {
        self.availabilityValue = availabilityValue
        self.enabled = enabled
        self.manualBackupResult = manualBackupResult
        self.latestBackupAt = lastBackupAt
    }

    func availability() async -> CloudBackupAvailability {
        availabilityValue
    }

    func isBackupEnabled() -> Bool {
        enabled
    }

    func setBackupEnabled(_ enabled: Bool) throws {
        if let error = setBackupEnabledErrorForValue[enabled] {
            throw error
        }
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

private final class FakeSubscriptionServiceForBackupSettings: SubscriptionService {
    let fetchStatusResult: Result<SubscriptionStatus, Error>

    init(fetchStatusResult: Result<SubscriptionStatus, Error>) {
        self.fetchStatusResult = fetchStatusResult
    }

    func fetchStatus(forceRefresh _: Bool) async throws -> SubscriptionStatus {
        try fetchStatusResult.get()
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
