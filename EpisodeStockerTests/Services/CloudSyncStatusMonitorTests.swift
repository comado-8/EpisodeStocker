import CoreData
import XCTest
@testable import EpisodeStocker

@MainActor
final class CloudSyncStatusMonitorTests: XCTestCase {
    func testStartPublishesInitialSnapshotAndSecondStartReplaysSnapshot() {
        let expectedDate = Date(timeIntervalSince1970: 55)
        let preferences = StubCloudSyncPreferencesForMonitor(lastSyncAt: expectedDate)
        let monitor = CloudSyncStatusMonitor(
            notificationCenter: NotificationCenter(),
            preferenceRepository: preferences
        )
        var snapshots: [CloudSyncStatusSnapshot] = []
        monitor.onChange = { snapshots.append($0) }

        monitor.start()
        monitor.start()

        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots.first?.lastSyncAt, expectedDate)
        XCTAssertEqual(snapshots.last?.isSyncing, false)
    }

    func testImportStartSetsSyncingTrue() {
        let preferences = StubCloudSyncPreferencesForMonitor(lastSyncAt: nil)
        let monitor = CloudSyncStatusMonitor(preferenceRepository: preferences)
        var snapshots: [CloudSyncStatusSnapshot] = []
        monitor.onChange = { snapshots.append($0) }

        monitor.handle(event: .init(kind: .import, endDate: nil, errorDescription: nil))

        XCTAssertEqual(snapshots.last?.isSyncing, true)
    }

    func testOverlappingEventsKeepSyncingTrueUntilAllFinished() {
        let preferences = StubCloudSyncPreferencesForMonitor(lastSyncAt: nil)
        let monitor = CloudSyncStatusMonitor(preferenceRepository: preferences)
        var snapshots: [CloudSyncStatusSnapshot] = []
        monitor.onChange = { snapshots.append($0) }
        let firstID = UUID()
        let secondID = UUID()

        monitor.handle(event: .init(id: firstID, kind: .import, endDate: nil, errorDescription: nil))
        monitor.handle(event: .init(id: secondID, kind: .export, endDate: nil, errorDescription: nil))
        monitor.handle(event: .init(id: firstID, kind: .import, endDate: Date(), errorDescription: nil))

        XCTAssertEqual(snapshots.last?.isSyncing, true)

        monitor.handle(event: .init(id: secondID, kind: .export, endDate: Date(), errorDescription: nil))

        XCTAssertEqual(snapshots.last?.isSyncing, false)
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

    func testStopClearsSyncingStateAndNextStartReportsIdle() {
        let preferences = StubCloudSyncPreferencesForMonitor(lastSyncAt: nil)
        let monitor = CloudSyncStatusMonitor(
            notificationCenter: NotificationCenter(),
            preferenceRepository: preferences
        )
        var snapshots: [CloudSyncStatusSnapshot] = []
        monitor.onChange = { snapshots.append($0) }

        monitor.start()
        monitor.handle(event: .init(kind: .import, endDate: nil, errorDescription: nil))
        XCTAssertEqual(snapshots.last?.isSyncing, true)

        monitor.stop()
        monitor.start()

        XCTAssertEqual(snapshots.last?.isSyncing, false)
    }

    func testHandleIgnoresNonSyncOperationEvent() {
        let preferences = StubCloudSyncPreferencesForMonitor(lastSyncAt: nil)
        let monitor = CloudSyncStatusMonitor(preferenceRepository: preferences)
        var snapshots: [CloudSyncStatusSnapshot] = []
        monitor.onChange = { snapshots.append($0) }

        monitor.handle(event: .init(kind: .setup, endDate: Date(), errorDescription: nil))

        XCTAssertTrue(snapshots.isEmpty)
    }

    func testCloudSyncEventKindMapping() {
        XCTAssertEqual(
            CloudSyncStatusMonitor.cloudSyncEventKind(from: .setup),
            .setup
        )
        XCTAssertEqual(
            CloudSyncStatusMonitor.cloudSyncEventKind(from: .import),
            .import
        )
        XCTAssertEqual(
            CloudSyncStatusMonitor.cloudSyncEventKind(from: .export),
            .export
        )
    }

    func testMakeCloudSyncEventFromTypeBuilder() {
        let id = UUID()
        let endDate = Date(timeIntervalSince1970: 900)
        let event = CloudSyncStatusMonitor.makeCloudSyncEvent(
            id: id,
            type: .import,
            endDate: endDate,
            errorDescription: "oops"
        )

        XCTAssertEqual(
            event,
            .init(id: id, kind: .import, endDate: endDate, errorDescription: "oops")
        )
    }

    func testMakeCloudSyncEventFromNotificationWithoutPayloadReturnsNil() {
        let notification = Notification(name: .NSPersistentStoreRemoteChange)
        XCTAssertNil(CloudSyncStatusMonitor.makeCloudSyncEvent(from: notification))
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
