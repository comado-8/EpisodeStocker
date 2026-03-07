import Foundation

struct ManualBackupManifest: Codable, Equatable {
    let schemaVersion: Int
    let createdAt: Date
    let appVersion: String?
}

struct ManualBackupEncryptionInfo: Codable, Equatable {
    let algorithm: String
    let keyDerivation: String
    let iterations: Int
    let salt: Data
}

struct ManualBackupEnvelope: Codable, Equatable {
    let manifest: ManualBackupManifest
    let encryption: ManualBackupEncryptionInfo
    let sealedBoxCombined: Data
}

struct ManualBackupPayloadV1: Codable, Equatable {
    struct EpisodeRecord: Codable, Equatable {
        let id: UUID
        let date: Date
        let title: String
        let body: String?
        let unlockDate: Date?
        let type: String?
        let createdAt: Date
        let updatedAt: Date
        let isSoftDeleted: Bool
        let deletedAt: Date?
        let tagIDs: [UUID]
        let personIDs: [UUID]
        let projectIDs: [UUID]
        let emotionIDs: [UUID]
        let placeIDs: [UUID]
    }

    struct UnlockLogRecord: Codable, Equatable {
        let id: UUID
        let talkedAt: Date
        let mediaPublicAt: Date?
        let mediaType: String?
        let projectNameText: String?
        let reaction: String
        let memo: String
        let createdAt: Date
        let updatedAt: Date
        let isSoftDeleted: Bool
        let deletedAt: Date?
        let episodeID: UUID
    }

    struct TagRecord: Codable, Equatable {
        let id: UUID
        let name: String
        let nameNormalized: String
        let createdAt: Date
        let updatedAt: Date
        let isSoftDeleted: Bool
        let deletedAt: Date?
    }

    struct PersonRecord: Codable, Equatable {
        let id: UUID
        let name: String
        let nameNormalized: String
        let createdAt: Date
        let updatedAt: Date
        let isSoftDeleted: Bool
        let deletedAt: Date?
    }

    struct ProjectRecord: Codable, Equatable {
        let id: UUID
        let name: String
        let nameNormalized: String
        let createdAt: Date
        let updatedAt: Date
        let isSoftDeleted: Bool
        let deletedAt: Date?
    }

    struct EmotionRecord: Codable, Equatable {
        let id: UUID
        let name: String
        let nameNormalized: String
        let createdAt: Date
        let updatedAt: Date
        let isSoftDeleted: Bool
        let deletedAt: Date?
    }

    struct PlaceRecord: Codable, Equatable {
        let id: UUID
        let name: String
        let nameNormalized: String
        let createdAt: Date
        let updatedAt: Date
        let isSoftDeleted: Bool
        let deletedAt: Date?
    }

    let episodes: [EpisodeRecord]
    let unlockLogs: [UnlockLogRecord]
    let tags: [TagRecord]
    let persons: [PersonRecord]
    let projects: [ProjectRecord]
    let emotions: [EmotionRecord]
    let places: [PlaceRecord]
}

struct ManualBackupPreview: Equatable {
    let manifest: ManualBackupManifest
    let episodeCount: Int
    let unlockLogCount: Int
    let tagCount: Int
    let personCount: Int
    let projectCount: Int
    let emotionCount: Int
    let placeCount: Int

    var totalRecordCount: Int {
        episodeCount
            + unlockLogCount
            + tagCount
            + personCount
            + projectCount
            + emotionCount
            + placeCount
    }
}

struct ManualRestoreResult: Equatable {
    let restoredAt: Date
    let preview: ManualBackupPreview
}

enum ManualBackupError: LocalizedError, Equatable {
    case invalidPassphrase
    case invalidFormat
    case unsupportedVersion(Int)
    case wrongPassphrase
    case decryptFailed
    case encryptFailed
    case fileReadFailed
    case fileWriteFailed
    case validationFailed(reason: String)
    case restoreFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidPassphrase:
            return "パスフレーズは8文字以上で入力してください。"
        case .invalidFormat:
            return "バックアップファイルの形式が不正です。"
        case .unsupportedVersion(let version):
            return "未対応のバックアップ形式です（version: \(version)）。"
        case .wrongPassphrase:
            return "パスフレーズが正しくありません。"
        case .decryptFailed:
            return "バックアップファイルの復号に失敗しました。"
        case .encryptFailed:
            return "バックアップファイルの暗号化に失敗しました。"
        case .fileReadFailed:
            return "バックアップファイルを読み込めませんでした。"
        case .fileWriteFailed:
            return "バックアップファイルを書き込めませんでした。"
        case .validationFailed(let reason):
            return "バックアップ内容の検証に失敗しました: \(reason)"
        case .restoreFailed(let reason):
            return "バックアップの復元に失敗しました: \(reason)"
        }
    }
}

protocol ManualBackupService {
    func exportEncryptedBackup(passphrase: String) async throws -> URL
    func inspectEncryptedBackup(at url: URL, passphrase: String) async throws -> ManualBackupPreview
    func restoreEncryptedBackup(at url: URL, passphrase: String) async throws -> ManualRestoreResult
}
