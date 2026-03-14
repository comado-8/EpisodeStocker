import CloudKit
import Foundation

protocol CloudBackupJobRunner {
    func runBackupRequest() async throws
}

struct NoopCloudBackupJobRunner: CloudBackupJobRunner {
    func runBackupRequest() async throws {
        // MVP: 実データ同期は次フェーズで実装する。
    }
}

final class CloudKitBackupService: CloudBackupService {
    static let appleAccountSignInRequiredReason = "iCloudにサインインしてください。"
    static let migrationPendingReason = "同期準備中です。アプリを再起動して続行してください。"
    static let runtimeDisabledReason = "このビルドではクラウド同期を開始できません。アプリ更新後に再度お試しください。"

    private let cloudKitClient: CloudKitClient
    private let settingsRepository: SettingsRepository
    private let preferenceRepository: CloudSyncPreferenceRepository
    private let cloudSyncModeResolver: CloudSyncModeResolving
    private let backupJobRunner: CloudBackupJobRunner
    private let now: () -> Date

    init(
        cloudKitClient: CloudKitClient = DefaultCloudKitClient(),
        settingsRepository: SettingsRepository = UserDefaultsSettingsRepository(),
        cloudSyncModeResolver: CloudSyncModeResolving? = nil,
        backupJobRunner: CloudBackupJobRunner = NoopCloudBackupJobRunner(),
        now: @escaping () -> Date = Date.init
    ) {
        let preferenceRepository = UserDefaultsCloudSyncPreferenceRepository(settingsRepository: settingsRepository)
        let entitlementCache = UserDefaultsSubscriptionEntitlementCache(settingsRepository: settingsRepository)
        self.cloudKitClient = cloudKitClient
        self.settingsRepository = settingsRepository
        self.preferenceRepository = preferenceRepository
        self.cloudSyncModeResolver = cloudSyncModeResolver
            ?? DefaultCloudSyncModeResolver(
                preferenceRepository: preferenceRepository,
                entitlementCache: entitlementCache
            )
        self.backupJobRunner = backupJobRunner
        self.now = now
    }

    func availability() async -> CloudBackupAvailability {
        if settingsRepository.bool(for: .cloudSyncRuntimeDisabled) {
            return .unavailable(reason: Self.runtimeDisabledReason)
        }
        if preferenceRepository.isCloudSyncRequested()
            && !settingsRepository.bool(for: .cloudSyncMigrationPrepared)
        {
            return .unavailable(reason: Self.migrationPendingReason)
        }

        do {
            let status = try await cloudKitClient.accountStatus()
            switch status {
            case .available:
                return .available
            case .noAccount:
                return .unavailable(reason: Self.appleAccountSignInRequiredReason)
            case .restricted:
                return .unavailable(reason: "このデバイスではiCloudが制限されています。")
            case .couldNotDetermine:
                return .unavailable(reason: "iCloudの状態を確認できません。")
            case .temporarilyUnavailable:
                return .unavailable(reason: "iCloudが一時的に利用できません。")
            @unknown default:
                return .unavailable(reason: "iCloudの状態が未対応です。")
            }
        } catch {
            return .unavailable(reason: "iCloudの状態確認に失敗しました。")
        }
    }

    func isBackupEnabled() -> Bool {
        preferenceRepository.isCloudSyncRequested()
    }

    func setBackupEnabled(_ enabled: Bool) throws {
        preferenceRepository.setCloudSyncRequested(enabled)
    }

    func runManualBackup() async throws -> Date {
        switch cloudSyncModeResolver.resolveEffectiveCloudSyncMode() {
        case .enabled:
            break
        case .denied:
            throw CloudBackupError.notEntitled
        case .unknown, .disabled:
            throw CloudBackupError.backupDisabled
        }

        let currentAvailability = await availability()
        guard case .available = currentAvailability else {
            if case .unavailable(let reason) = currentAvailability {
                throw CloudBackupError.unavailable(reason: reason)
            }
            throw CloudBackupError.unavailable(reason: "iCloudが利用できません。")
        }

        do {
            try await backupJobRunner.runBackupRequest()
            let executedAt = now()
            return executedAt
        } catch let error as CloudBackupError {
            throw error
        } catch {
            throw CloudBackupError.failed(reason: "バックアップの実行に失敗しました。")
        }
    }

    func lastBackupAt() -> Date? {
        preferenceRepository.lastSyncAt()
    }
}
