import CoreData
import Foundation

struct CloudSyncStatusSnapshot: Equatable {
    var isSyncing: Bool
    var lastSyncAt: Date?
    var lastErrorMessage: String?
}

struct CloudSyncEvent: Equatable {
    enum Kind: Equatable {
        case setup
        case `import`
        case export
        case other
    }

    let kind: Kind
    let endDate: Date?
    let errorDescription: String?

    var isSyncOperation: Bool {
        kind == .import || kind == .export
    }
}

protocol CloudSyncStatusMonitoring: AnyObject {
    var onChange: ((CloudSyncStatusSnapshot) -> Void)? { get set }
    func start()
    func stop()
}

final class CloudSyncStatusMonitor: CloudSyncStatusMonitoring {
    var onChange: ((CloudSyncStatusSnapshot) -> Void)?

    private let notificationCenter: NotificationCenter
    private let preferenceRepository: CloudSyncPreferenceRepository

    private var observer: NSObjectProtocol?
    private var snapshot: CloudSyncStatusSnapshot

    init(
        notificationCenter: NotificationCenter = .default,
        preferenceRepository: CloudSyncPreferenceRepository = UserDefaultsCloudSyncPreferenceRepository()
    ) {
        self.notificationCenter = notificationCenter
        self.preferenceRepository = preferenceRepository
        self.snapshot = CloudSyncStatusSnapshot(
            isSyncing: false,
            lastSyncAt: preferenceRepository.lastSyncAt(),
            lastErrorMessage: nil
        )
    }

    deinit {
        if let observer {
            notificationCenter.removeObserver(observer)
        }
    }

    func start() {
        guard observer == nil else {
            onChange?(snapshot)
            return
        }

        observer = notificationCenter.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let event = Self.makeCloudSyncEvent(from: notification) else { return }
            self.handle(event: event)
        }
        onChange?(snapshot)
    }

    func stop() {
        guard let observer else { return }
        notificationCenter.removeObserver(observer)
        self.observer = nil
    }

    func handle(event: CloudSyncEvent) {
        guard event.isSyncOperation else { return }

        if event.endDate == nil {
            snapshot.isSyncing = true
            snapshot.lastErrorMessage = nil
            onChange?(snapshot)
            return
        }

        snapshot.isSyncing = false

        if let errorDescription = event.errorDescription {
            snapshot.lastErrorMessage = errorDescription
            onChange?(snapshot)
            return
        }

        guard let syncedAt = event.endDate else { return }
        preferenceRepository.setLastSyncAt(syncedAt)
        snapshot.lastSyncAt = syncedAt
        snapshot.lastErrorMessage = nil
        onChange?(snapshot)
    }

    private static func makeCloudSyncEvent(from notification: Notification) -> CloudSyncEvent? {
        guard
            let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event
        else {
            return nil
        }

        let kind: CloudSyncEvent.Kind
        switch event.type {
        case .setup:
            kind = .setup
        case .import:
            kind = .import
        case .export:
            kind = .export
        @unknown default:
            kind = .other
        }

        return CloudSyncEvent(
            kind: kind,
            endDate: event.endDate,
            errorDescription: event.error?.localizedDescription
        )
    }
}
