import Foundation

enum CloudBackupAvailability: Equatable {
    case available
    case unavailable(reason: String)
}

enum CloudBackupError: LocalizedError, Equatable {
    case unavailable(reason: String)
    case notEntitled
    case failed(reason: String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return reason
        case .notEntitled:
            return "バックアップ機能はサブスクリプション登録で利用できます。"
        case .failed(let reason):
            return reason
        }
    }
}

protocol CloudBackupService {
    func availability() async -> CloudBackupAvailability
    func isBackupEnabled() -> Bool
    func setBackupEnabled(_ enabled: Bool) throws
    func runManualBackup() async throws -> Date
    func lastBackupAt() -> Date?
}
