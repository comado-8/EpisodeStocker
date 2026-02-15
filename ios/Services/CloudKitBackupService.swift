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
    private let cloudKitClient: CloudKitClient
    private let settingsRepository: SettingsRepository
    private let backupJobRunner: CloudBackupJobRunner
    private let now: () -> Date

    init(
        cloudKitClient: CloudKitClient = DefaultCloudKitClient(),
        settingsRepository: SettingsRepository = UserDefaultsSettingsRepository(),
        backupJobRunner: CloudBackupJobRunner = NoopCloudBackupJobRunner(),
        now: @escaping () -> Date = Date.init
    ) {
        self.cloudKitClient = cloudKitClient
        self.settingsRepository = settingsRepository
        self.backupJobRunner = backupJobRunner
        self.now = now
    }

    func availability() async -> CloudBackupAvailability {
        do {
            let status = try await cloudKitClient.accountStatus()
            switch status {
            case .available:
                return .available
            case .noAccount:
                return .unavailable(reason: "iCloudにサインインしてください。")
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
        settingsRepository.bool(for: .cloudBackupEnabled)
    }

    func setBackupEnabled(_ enabled: Bool) throws {
        settingsRepository.set(enabled, for: .cloudBackupEnabled)
    }

    func runManualBackup() async throws -> Date {
        guard isBackupEnabled() else {
            throw CloudBackupError.failed(reason: "クラウドバックアップがオフです。")
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
            settingsRepository.set(executedAt, for: .cloudBackupLastRunAt)
            return executedAt
        } catch let error as CloudBackupError {
            throw error
        } catch {
            throw CloudBackupError.failed(reason: "バックアップの実行に失敗しました。")
        }
    }

    func lastBackupAt() -> Date? {
        settingsRepository.date(for: .cloudBackupLastRunAt)
    }
}
