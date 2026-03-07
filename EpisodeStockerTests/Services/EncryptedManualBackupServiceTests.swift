import Foundation
import SwiftData
import XCTest
@testable import EpisodeStocker

@MainActor
final class EncryptedManualBackupServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var settings: InMemoryManualBackupSettingsRepository!
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = TestModelContainerFactory.makeInMemoryContainer()
        context = ModelContext(container)
        settings = InMemoryManualBackupSettingsRepository()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EncryptedManualBackupServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        container = nil
        context = nil
        settings = nil
        tempDirectory = nil
        try super.tearDownWithError()
    }

    func testExportInspectAndRestoreReplacesData() async throws {
        let original = try seedPrimaryRecord()
        let exportDate = Date(timeIntervalSince1970: 500)
        var now = exportDate

        let service = makeService(now: { now })
        let exportedURL = try await service.exportEncryptedBackup(passphrase: "passphrase-123")

        XCTAssertTrue(FileManager.default.fileExists(atPath: exportedURL.path))
        XCTAssertEqual(settings.date(for: .manualBackupLastExportAt), exportDate)

        let preview = try await service.inspectEncryptedBackup(at: exportedURL, passphrase: "passphrase-123")
        XCTAssertEqual(preview.episodeCount, 1)
        XCTAssertEqual(preview.unlockLogCount, 1)
        XCTAssertEqual(preview.tagCount, 1)
        XCTAssertEqual(preview.personCount, 1)
        XCTAssertEqual(preview.projectCount, 1)
        XCTAssertEqual(preview.emotionCount, 1)
        XCTAssertEqual(preview.placeCount, 1)

        try replaceWithSecondaryRecord()

        now = Date(timeIntervalSince1970: 700)
        let restoreResult = try await service.restoreEncryptedBackup(at: exportedURL, passphrase: "passphrase-123")

        XCTAssertEqual(restoreResult.restoredAt, now)
        XCTAssertEqual(settings.date(for: .manualBackupLastRestoreAt), now)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes.first?.id, original.episodeID)
        XCTAssertEqual(episodes.first?.title, "first")
        XCTAssertEqual(episodes.first?.tags.map(\.id), [original.tagID])
        XCTAssertEqual(episodes.first?.persons.map(\.id), [original.personID])
        XCTAssertEqual(episodes.first?.projects.map(\.id), [original.projectID])
        XCTAssertEqual(episodes.first?.emotions.map(\.id), [original.emotionID])
        XCTAssertEqual(episodes.first?.places.map(\.id), [original.placeID])

        let unlockLogs = try context.fetch(FetchDescriptor<UnlockLog>())
        XCTAssertEqual(unlockLogs.count, 1)
        XCTAssertEqual(unlockLogs.first?.id, original.unlockLogID)
        XCTAssertEqual(unlockLogs.first?.episode.id, original.episodeID)
    }

    func testInspectWithWrongPassphraseThrowsWrongPassphrase() async throws {
        _ = try seedPrimaryRecord()
        let service = makeService(now: Date.init)
        let exportedURL = try await service.exportEncryptedBackup(passphrase: "passphrase-123")

        do {
            _ = try await service.inspectEncryptedBackup(at: exportedURL, passphrase: "invalid-passphrase")
            XCTFail("Expected failure")
        } catch let error as ManualBackupError {
            XCTAssertEqual(error, .wrongPassphrase)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeService(now: @escaping () -> Date) -> EncryptedManualBackupService {
        EncryptedManualBackupService(
            modelContext: context,
            settingsRepository: settings,
            fileManager: .default,
            backupDirectory: tempDirectory,
            now: now,
            appVersionProvider: { "1.0.0" },
            fileCodec: ManualBackupFileCodec(now: now)
        )
    }

    private func seedPrimaryRecord() throws -> SeedIDs {
        try wipeAll()
        let date = Date(timeIntervalSince1970: 100)

        let tagID = UUID(uuidString: "A0000000-0000-0000-0000-000000000001")!
        let personID = UUID(uuidString: "A0000000-0000-0000-0000-000000000002")!
        let projectID = UUID(uuidString: "A0000000-0000-0000-0000-000000000003")!
        let emotionID = UUID(uuidString: "A0000000-0000-0000-0000-000000000004")!
        let placeID = UUID(uuidString: "A0000000-0000-0000-0000-000000000005")!
        let episodeID = UUID(uuidString: "A0000000-0000-0000-0000-000000000006")!
        let unlockLogID = UUID(uuidString: "A0000000-0000-0000-0000-000000000007")!

        let tag = Tag(id: tagID, name: "tag1", nameNormalized: "tag1", createdAt: date, updatedAt: date)
        let person = Person(id: personID, name: "person1", nameNormalized: "person1", createdAt: date, updatedAt: date)
        let project = Project(id: projectID, name: "project1", nameNormalized: "project1", createdAt: date, updatedAt: date)
        let emotion = Emotion(id: emotionID, name: "emotion1", nameNormalized: "emotion1", createdAt: date, updatedAt: date)
        let place = Place(id: placeID, name: "place1", nameNormalized: "place1", createdAt: date, updatedAt: date)

        let episode = Episode(
            id: episodeID,
            date: date,
            title: "first",
            body: "body",
            unlockDate: nil,
            type: "type",
            createdAt: date,
            updatedAt: date,
            isSoftDeleted: false,
            deletedAt: nil,
            tags: [tag],
            persons: [person],
            projects: [project],
            emotions: [emotion],
            places: [place],
            unlockLogs: []
        )

        let unlockLog = UnlockLog(
            id: unlockLogID,
            talkedAt: date,
            mediaPublicAt: nil,
            mediaType: "配信",
            projectNameText: "project",
            reaction: ReleaseLogOutcome.hit.rawValue,
            memo: "memo",
            episode: episode,
            createdAt: date,
            updatedAt: date,
            isSoftDeleted: false,
            deletedAt: nil
        )

        context.insert(tag)
        context.insert(person)
        context.insert(project)
        context.insert(emotion)
        context.insert(place)
        context.insert(episode)
        context.insert(unlockLog)
        try context.save()

        return SeedIDs(
            tagID: tagID,
            personID: personID,
            projectID: projectID,
            emotionID: emotionID,
            placeID: placeID,
            episodeID: episodeID,
            unlockLogID: unlockLogID
        )
    }

    private func replaceWithSecondaryRecord() throws {
        try wipeAll()
        let date = Date(timeIntervalSince1970: 200)

        let episode = Episode(
            date: date,
            title: "second",
            body: "other",
            unlockDate: nil,
            type: nil,
            createdAt: date,
            updatedAt: date
        )
        context.insert(episode)
        try context.save()
    }

    private func wipeAll() throws {
        for unlockLog in try context.fetch(FetchDescriptor<UnlockLog>()) {
            context.delete(unlockLog)
        }
        for episode in try context.fetch(FetchDescriptor<Episode>()) {
            context.delete(episode)
        }
        for tag in try context.fetch(FetchDescriptor<Tag>()) {
            context.delete(tag)
        }
        for person in try context.fetch(FetchDescriptor<Person>()) {
            context.delete(person)
        }
        for project in try context.fetch(FetchDescriptor<Project>()) {
            context.delete(project)
        }
        for emotion in try context.fetch(FetchDescriptor<Emotion>()) {
            context.delete(emotion)
        }
        for place in try context.fetch(FetchDescriptor<Place>()) {
            context.delete(place)
        }
        try context.save()
    }
}

private struct SeedIDs {
    let tagID: UUID
    let personID: UUID
    let projectID: UUID
    let emotionID: UUID
    let placeID: UUID
    let episodeID: UUID
    let unlockLogID: UUID
}

private final class InMemoryManualBackupSettingsRepository: SettingsRepository {
    private var boolStorage: [SettingsKey: Bool] = [:]
    private var dateStorage: [SettingsKey: Date] = [:]

    func bool(for key: SettingsKey) -> Bool {
        boolStorage[key] ?? false
    }

    func set(_ value: Bool, for key: SettingsKey) {
        boolStorage[key] = value
    }

    func optionalBool(for key: SettingsKey) -> Bool? {
        boolStorage[key]
    }

    func setOptionalBool(_ value: Bool?, for key: SettingsKey) {
        boolStorage[key] = value
    }

    func date(for key: SettingsKey) -> Date? {
        dateStorage[key]
    }

    func set(_ value: Date?, for key: SettingsKey) {
        dateStorage[key] = value
    }
}
