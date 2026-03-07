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

    let id: UUID
    let kind: Kind
    let endDate: Date?
    let errorDescription: String?

    init(
        id: UUID = UUID(),
        kind: Kind,
        endDate: Date?,
        errorDescription: String?
    ) {
        self.id = id
        self.kind = kind
        self.endDate = endDate
        self.errorDescription = errorDescription
    }

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
    private var activeSyncEventIDs: Set<UUID> = []

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
        activeSyncEventIDs.removeAll()
        snapshot.isSyncing = false
    }

    func handle(event: CloudSyncEvent) {
        guard event.isSyncOperation else { return }

        if event.endDate == nil {
            activeSyncEventIDs.insert(event.id)
            snapshot.isSyncing = !activeSyncEventIDs.isEmpty
            snapshot.lastErrorMessage = nil
            onChange?(snapshot)
            return
        }

        activeSyncEventIDs.remove(event.id)
        snapshot.isSyncing = !activeSyncEventIDs.isEmpty

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

    static func makeCloudSyncEvent(from notification: Notification) -> CloudSyncEvent? {
        guard
            let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event
        else {
            return nil
        }

        return makeCloudSyncEvent(
            id: event.identifier,
            type: event.type,
            endDate: event.endDate,
            errorDescription: event.error?.localizedDescription
        )
    }

    static func makeCloudSyncEvent(
        id: UUID,
        type: NSPersistentCloudKitContainer.EventType,
        endDate: Date?,
        errorDescription: String?
    ) -> CloudSyncEvent {
        CloudSyncEvent(
            id: id,
            kind: cloudSyncEventKind(from: type),
            endDate: endDate,
            errorDescription: errorDescription
        )
    }

    static func cloudSyncEventKind(
        from type: NSPersistentCloudKitContainer.EventType
    ) -> CloudSyncEvent.Kind {
        switch type {
        case .setup:
            return .setup
        case .import:
            return .import
        case .export:
            return .export
        @unknown default:
            return .other
        }
    }
}
