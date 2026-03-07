import Foundation
import SwiftData

@MainActor
final class EncryptedManualBackupService: ManualBackupService {
    static let minimumPassphraseLength = 8

    private let modelContext: ModelContext
    private let settingsRepository: SettingsRepository
    private let fileManager: FileManager
    private let backupDirectory: URL
    private let now: () -> Date
    private let appVersionProvider: () -> String?
    private let fileCodec: ManualBackupFileCodec

    init(
        modelContext: ModelContext,
        settingsRepository: SettingsRepository = UserDefaultsSettingsRepository(),
        fileManager: FileManager = .default,
        backupDirectory: URL? = nil,
        now: @escaping () -> Date = Date.init,
        appVersionProvider: @escaping () -> String? = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        },
        fileCodec: ManualBackupFileCodec = ManualBackupFileCodec()
    ) {
        self.modelContext = modelContext
        self.settingsRepository = settingsRepository
        self.fileManager = fileManager
        self.backupDirectory = backupDirectory
            ?? fileManager.temporaryDirectory.appendingPathComponent("manual-backups", isDirectory: true)
        self.now = now
        self.appVersionProvider = appVersionProvider
        self.fileCodec = fileCodec
    }

    func exportEncryptedBackup(passphrase: String) async throws -> URL {
        guard passphrase.count >= Self.minimumPassphraseLength else {
            throw ManualBackupError.invalidPassphrase
        }

        let payload = try await makePayloadSnapshot()
        let exportedAt = now()
        let outputURL = backupDirectory.appendingPathComponent(makeFilename(now: exportedAt))
        let appVersion = appVersionProvider()

        let backupData: Data
        do {
            backupData = try await runInBackground { [self] in
                try self.fileCodec.encode(
                    payload: payload,
                    passphrase: passphrase,
                    appVersion: appVersion
                )
            }
        } catch let error as ManualBackupError {
            throw error
        } catch {
            throw ManualBackupError.encryptFailed
        }

        do {
            try await runInBackground { [self] in
                try self.fileManager.createDirectory(at: self.backupDirectory, withIntermediateDirectories: true)
                try backupData.write(to: outputURL, options: .atomic)
            }
        } catch {
            throw ManualBackupError.fileWriteFailed
        }

        settingsRepository.set(exportedAt, for: .manualBackupLastExportAt)
        return outputURL
    }

    func inspectEncryptedBackup(at url: URL, passphrase: String) async throws -> ManualBackupPreview {
        guard passphrase.count >= Self.minimumPassphraseLength else {
            throw ManualBackupError.invalidPassphrase
        }
        let decoded = try await decodeBackup(at: url, passphrase: passphrase)
        return makePreview(from: decoded.manifest, payload: decoded.payload)
    }

    func restoreEncryptedBackup(at url: URL, passphrase: String) async throws -> ManualRestoreResult {
        guard passphrase.count >= Self.minimumPassphraseLength else {
            throw ManualBackupError.invalidPassphrase
        }

        let decoded = try await decodeBackup(at: url, passphrase: passphrase)
        try await validate(payload: decoded.payload)
        try await stageRestoreValidation(payload: decoded.payload)

        do {
            try Self.deleteAllExistingData(in: modelContext)
            try Self.restore(payload: decoded.payload, in: modelContext)
            try modelContext.save()
        } catch let error as ManualBackupError {
            throw error
        } catch {
            throw ManualBackupError.restoreFailed(reason: error.localizedDescription)
        }

        let restoredAt = now()
        settingsRepository.set(restoredAt, for: .manualBackupLastRestoreAt)
        return ManualRestoreResult(
            restoredAt: restoredAt,
            preview: makePreview(from: decoded.manifest, payload: decoded.payload)
        )
    }

    private func decodeBackup(at url: URL, passphrase: String) async throws -> DecodedManualBackup {
        let data: Data
        do {
            data = try await runInBackground {
                try Data(contentsOf: url)
            }
        } catch {
            throw ManualBackupError.fileReadFailed
        }

        do {
            return try await runInBackground { [self] in
                try self.fileCodec.decode(data, passphrase: passphrase)
            }
        } catch let error as ManualBackupError {
            throw error
        } catch {
            throw ManualBackupError.decryptFailed
        }
    }

    private func makePayloadSnapshot() async throws -> ManualBackupPayloadV1 {
        let episodes = try modelContext.fetch(FetchDescriptor<Episode>())
        let unlockLogs = try modelContext.fetch(FetchDescriptor<UnlockLog>())
        let tags = try modelContext.fetch(FetchDescriptor<Tag>())
        let persons = try modelContext.fetch(FetchDescriptor<Person>())
        let projects = try modelContext.fetch(FetchDescriptor<Project>())
        let emotions = try modelContext.fetch(FetchDescriptor<Emotion>())
        let places = try modelContext.fetch(FetchDescriptor<Place>())

        let episodeRecords = episodes.map {
            ManualBackupPayloadV1.EpisodeRecord(
                id: $0.id,
                date: $0.date,
                title: $0.title,
                body: $0.body,
                unlockDate: $0.unlockDate,
                type: $0.type,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt,
                isSoftDeleted: $0.isSoftDeleted,
                deletedAt: $0.deletedAt,
                tagIDs: $0.tags.map(\.id).sorted(by: Self.uuidLessThan),
                personIDs: $0.persons.map(\.id).sorted(by: Self.uuidLessThan),
                projectIDs: $0.projects.map(\.id).sorted(by: Self.uuidLessThan),
                emotionIDs: $0.emotions.map(\.id).sorted(by: Self.uuidLessThan),
                placeIDs: $0.places.map(\.id).sorted(by: Self.uuidLessThan)
            )
        }

        let unlockLogRecords = unlockLogs.map {
            ManualBackupPayloadV1.UnlockLogRecord(
                id: $0.id,
                talkedAt: $0.talkedAt,
                mediaPublicAt: $0.mediaPublicAt,
                mediaType: $0.mediaType,
                projectNameText: $0.projectNameText,
                reaction: $0.reaction,
                memo: $0.memo,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt,
                isSoftDeleted: $0.isSoftDeleted,
                deletedAt: $0.deletedAt,
                episodeID: $0.episode.id
            )
        }

        let tagRecords = tags.map {
            ManualBackupPayloadV1.TagRecord(
                id: $0.id,
                name: $0.name,
                nameNormalized: $0.nameNormalized,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt,
                isSoftDeleted: $0.isSoftDeleted,
                deletedAt: $0.deletedAt
            )
        }

        let personRecords = persons.map {
            ManualBackupPayloadV1.PersonRecord(
                id: $0.id,
                name: $0.name,
                nameNormalized: $0.nameNormalized,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt,
                isSoftDeleted: $0.isSoftDeleted,
                deletedAt: $0.deletedAt
            )
        }

        let projectRecords = projects.map {
            ManualBackupPayloadV1.ProjectRecord(
                id: $0.id,
                name: $0.name,
                nameNormalized: $0.nameNormalized,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt,
                isSoftDeleted: $0.isSoftDeleted,
                deletedAt: $0.deletedAt
            )
        }

        let emotionRecords = emotions.map {
            ManualBackupPayloadV1.EmotionRecord(
                id: $0.id,
                name: $0.name,
                nameNormalized: $0.nameNormalized,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt,
                isSoftDeleted: $0.isSoftDeleted,
                deletedAt: $0.deletedAt
            )
        }

        let placeRecords = places.map {
            ManualBackupPayloadV1.PlaceRecord(
                id: $0.id,
                name: $0.name,
                nameNormalized: $0.nameNormalized,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt,
                isSoftDeleted: $0.isSoftDeleted,
                deletedAt: $0.deletedAt
            )
        }

        return try await runInBackground {
            ManualBackupPayloadV1(
                episodes: episodeRecords.sorted { Self.uuidLessThan($0.id, $1.id) },
                unlockLogs: unlockLogRecords.sorted { Self.uuidLessThan($0.id, $1.id) },
                tags: tagRecords.sorted { Self.uuidLessThan($0.id, $1.id) },
                persons: personRecords.sorted { Self.uuidLessThan($0.id, $1.id) },
                projects: projectRecords.sorted { Self.uuidLessThan($0.id, $1.id) },
                emotions: emotionRecords.sorted { Self.uuidLessThan($0.id, $1.id) },
                places: placeRecords.sorted { Self.uuidLessThan($0.id, $1.id) }
            )
        }
    }

    private func makePreview(from manifest: ManualBackupManifest, payload: ManualBackupPayloadV1) -> ManualBackupPreview {
        ManualBackupPreview(
            manifest: manifest,
            episodeCount: payload.episodes.count,
            unlockLogCount: payload.unlockLogs.count,
            tagCount: payload.tags.count,
            personCount: payload.persons.count,
            projectCount: payload.projects.count,
            emotionCount: payload.emotions.count,
            placeCount: payload.places.count
        )
    }

    private static func deleteAllExistingData(in context: ModelContext) throws {
        try deleteAll(UnlockLog.self, in: context)
        try deleteAll(Episode.self, in: context)
        try deleteAll(Tag.self, in: context)
        try deleteAll(Person.self, in: context)
        try deleteAll(Project.self, in: context)
        try deleteAll(Emotion.self, in: context)
        try deleteAll(Place.self, in: context)
    }

    private static func deleteAll<Model: PersistentModel>(_ modelType: Model.Type, in context: ModelContext) throws {
        let records = try context.fetch(FetchDescriptor<Model>())
        for record in records {
            context.delete(record)
        }
    }

    private static func restore(payload: ManualBackupPayloadV1, in context: ModelContext) throws {
        var tagsByID: [UUID: Tag] = [:]
        var personsByID: [UUID: Person] = [:]
        var projectsByID: [UUID: Project] = [:]
        var emotionsByID: [UUID: Emotion] = [:]
        var placesByID: [UUID: Place] = [:]
        var episodesByID: [UUID: Episode] = [:]

        for tag in payload.tags {
            let restored = Tag(
                id: tag.id,
                name: tag.name,
                nameNormalized: tag.nameNormalized,
                createdAt: tag.createdAt,
                updatedAt: tag.updatedAt,
                isSoftDeleted: tag.isSoftDeleted,
                deletedAt: tag.deletedAt,
                episodes: []
            )
            context.insert(restored)
            tagsByID[tag.id] = restored
        }

        for person in payload.persons {
            let restored = Person(
                id: person.id,
                name: person.name,
                nameNormalized: person.nameNormalized,
                createdAt: person.createdAt,
                updatedAt: person.updatedAt,
                isSoftDeleted: person.isSoftDeleted,
                deletedAt: person.deletedAt
            )
            context.insert(restored)
            personsByID[person.id] = restored
        }

        for project in payload.projects {
            let restored = Project(
                id: project.id,
                name: project.name,
                nameNormalized: project.nameNormalized,
                createdAt: project.createdAt,
                updatedAt: project.updatedAt,
                isSoftDeleted: project.isSoftDeleted,
                deletedAt: project.deletedAt
            )
            context.insert(restored)
            projectsByID[project.id] = restored
        }

        for emotion in payload.emotions {
            let restored = Emotion(
                id: emotion.id,
                name: emotion.name,
                nameNormalized: emotion.nameNormalized,
                createdAt: emotion.createdAt,
                updatedAt: emotion.updatedAt,
                isSoftDeleted: emotion.isSoftDeleted,
                deletedAt: emotion.deletedAt
            )
            context.insert(restored)
            emotionsByID[emotion.id] = restored
        }

        for place in payload.places {
            let restored = Place(
                id: place.id,
                name: place.name,
                nameNormalized: place.nameNormalized,
                createdAt: place.createdAt,
                updatedAt: place.updatedAt,
                isSoftDeleted: place.isSoftDeleted,
                deletedAt: place.deletedAt
            )
            context.insert(restored)
            placesByID[place.id] = restored
        }

        for episode in payload.episodes {
            let restored = Episode(
                id: episode.id,
                date: episode.date,
                title: episode.title,
                body: episode.body,
                unlockDate: episode.unlockDate,
                type: episode.type,
                createdAt: episode.createdAt,
                updatedAt: episode.updatedAt,
                isSoftDeleted: episode.isSoftDeleted,
                deletedAt: episode.deletedAt,
                tags: [],
                persons: [],
                projects: [],
                emotions: [],
                places: [],
                unlockLogs: []
            )
            context.insert(restored)
            episodesByID[episode.id] = restored
        }

        for unlockLog in payload.unlockLogs {
            guard let episode = episodesByID[unlockLog.episodeID] else {
                throw ManualBackupError.validationFailed(reason: "UnlockLog が参照する Episode が存在しません。")
            }
            let restored = UnlockLog(
                id: unlockLog.id,
                talkedAt: unlockLog.talkedAt,
                mediaPublicAt: unlockLog.mediaPublicAt,
                mediaType: unlockLog.mediaType,
                projectNameText: unlockLog.projectNameText,
                reaction: unlockLog.reaction,
                memo: unlockLog.memo,
                episode: episode,
                createdAt: unlockLog.createdAt,
                updatedAt: unlockLog.updatedAt,
                isSoftDeleted: unlockLog.isSoftDeleted,
                deletedAt: unlockLog.deletedAt
            )
            context.insert(restored)
        }

        for episode in payload.episodes {
            guard let restored = episodesByID[episode.id] else {
                throw ManualBackupError.validationFailed(reason: "Episode の復元中に参照解決に失敗しました。")
            }
            restored.tags = episode.tagIDs.compactMap { tagsByID[$0] }
            restored.persons = episode.personIDs.compactMap { personsByID[$0] }
            restored.projects = episode.projectIDs.compactMap { projectsByID[$0] }
            restored.emotions = episode.emotionIDs.compactMap { emotionsByID[$0] }
            restored.places = episode.placeIDs.compactMap { placesByID[$0] }
        }
    }

    private func validate(payload: ManualBackupPayloadV1) async throws {
        try await runInBackground {
            try Self.validatePayload(payload)
        }
    }

    private static func validatePayload(_ payload: ManualBackupPayloadV1) throws {
        try validateUniqueIDs(payload.episodes.map(\.id), label: "Episode")
        try validateUniqueIDs(payload.unlockLogs.map(\.id), label: "UnlockLog")
        try validateUniqueIDs(payload.tags.map(\.id), label: "Tag")
        try validateUniqueIDs(payload.persons.map(\.id), label: "Person")
        try validateUniqueIDs(payload.projects.map(\.id), label: "Project")
        try validateUniqueIDs(payload.emotions.map(\.id), label: "Emotion")
        try validateUniqueIDs(payload.places.map(\.id), label: "Place")

        let tagIDs = Set(payload.tags.map(\.id))
        let personIDs = Set(payload.persons.map(\.id))
        let projectIDs = Set(payload.projects.map(\.id))
        let emotionIDs = Set(payload.emotions.map(\.id))
        let placeIDs = Set(payload.places.map(\.id))
        let episodeIDs = Set(payload.episodes.map(\.id))

        for episode in payload.episodes {
            for tagID in episode.tagIDs where !tagIDs.contains(tagID) {
                throw ManualBackupError.validationFailed(reason: "Episode が存在しない Tag を参照しています。")
            }
            for personID in episode.personIDs where !personIDs.contains(personID) {
                throw ManualBackupError.validationFailed(reason: "Episode が存在しない Person を参照しています。")
            }
            for projectID in episode.projectIDs where !projectIDs.contains(projectID) {
                throw ManualBackupError.validationFailed(reason: "Episode が存在しない Project を参照しています。")
            }
            for emotionID in episode.emotionIDs where !emotionIDs.contains(emotionID) {
                throw ManualBackupError.validationFailed(reason: "Episode が存在しない Emotion を参照しています。")
            }
            for placeID in episode.placeIDs where !placeIDs.contains(placeID) {
                throw ManualBackupError.validationFailed(reason: "Episode が存在しない Place を参照しています。")
            }
        }

        for unlockLog in payload.unlockLogs where !episodeIDs.contains(unlockLog.episodeID) {
            throw ManualBackupError.validationFailed(reason: "UnlockLog が存在しない Episode を参照しています。")
        }
    }

    private static func validateUniqueIDs(_ ids: [UUID], label: String) throws {
        var seen = Set<UUID>()
        for id in ids {
            if !seen.insert(id).inserted {
                throw ManualBackupError.validationFailed(reason: "\(label) に重複IDが含まれています。")
            }
        }
    }

    private func stageRestoreValidation(payload: ManualBackupPayloadV1) async throws {
        try await runInBackground {
            let configuration = ModelConfiguration(
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: Episode.self,
                UnlockLog.self,
                Tag.self,
                Person.self,
                Project.self,
                Emotion.self,
                Place.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            try Self.restore(payload: payload, in: context)
            try context.save()
        }
    }

    private func runInBackground<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func makeFilename(now: Date) -> String {
        "EpisodeStockerBackup_\(Self.filenameTimestampFormatter.string(from: now)).esbackup"
    }

    private static let filenameTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    private static func uuidLessThan(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}
