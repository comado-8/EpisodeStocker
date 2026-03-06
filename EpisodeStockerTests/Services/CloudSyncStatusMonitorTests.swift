import XCTest
@testable import EpisodeStocker

@MainActor
final class CloudSyncStatusMonitorTests: XCTestCase {
    func testImportStartSetsSyncingTrue() {
        let preferences = StubCloudSyncPreferencesForMonitor(lastSyncAt: nil)
        let monitor = CloudSyncStatusMonitor(preferenceRepository: preferences)
        var snapshots: [CloudSyncStatusSnapshot] = []
        monitor.onChange = { snapshots.append($0) }

        monitor.handle(event: .init(kind: .import, endDate: nil, errorDescription: nil))

        XCTAssertEqual(snapshots.last?.isSyncing, true)
    }

    func testExportSuccessStoresLastSyncAtAndStopsSyncing() {
        let preferences = StubCloudSyncPreferencesForMonitor(lastSyncAt: nil)
        let monitor = CloudSyncStatusMonitor(preferenceRepository: preferences)
        var snapshots: [CloudSyncStatusSnapshot] = []
        monitor.onChange = { snapshots.append($0) }
        let endDate = Date(timeIntervalSince1970: 12_345)

        monitor.handle(event: .init(kind: .export, endDate: endDate, errorDescription: nil))

        XCTAssertEqual(preferences.lastSyncAt(), endDate)
        XCTAssertEqual(snapshots.last?.lastSyncAt, endDate)
        XCTAssertEqual(snapshots.last?.isSyncing, false)
    }

    func testImportFailurePublishesErrorAndStopsSyncing() {
        let preferences = StubCloudSyncPreferencesForMonitor(lastSyncAt: nil)
        let monitor = CloudSyncStatusMonitor(preferenceRepository: preferences)
        var snapshots: [CloudSyncStatusSnapshot] = []
        monitor.onChange = { snapshots.append($0) }

        monitor.handle(event: .init(kind: .import, endDate: Date(), errorDescription: "sync failed"))

        XCTAssertEqual(snapshots.last?.isSyncing, false)
        XCTAssertEqual(snapshots.last?.lastErrorMessage, "sync failed")
    }
}

private final class StubCloudSyncPreferencesForMonitor: CloudSyncPreferenceRepository {
    private var requested = false
    private var syncDate: Date?

    init(lastSyncAt: Date?) {
        syncDate = lastSyncAt
    }

    func isCloudSyncRequested() -> Bool {
        requested
    }

    func setCloudSyncRequested(_ requested: Bool) {
        self.requested = requested
    }

    func lastSyncAt() -> Date? {
        syncDate
    }

    func setLastSyncAt(_ date: Date?) {
        syncDate = date
    }
}
