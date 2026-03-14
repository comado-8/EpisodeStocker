import SwiftData
import XCTest
@testable import EpisodeStocker

@MainActor
final class CloudSyncDataPreparationServiceTests: XCTestCase {
    func testPrepareIfNeededDeduplicatesRelationsAndRemovesOrphans() throws {
        let container = TestModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = InMemoryPreparationSettingsRepository()

        let episode = Episode(date: Date(timeIntervalSince1970: 1), title: "E1")
        context.insert(episode)

        let tagA = Tag(name: "Work", nameNormalized: "work")
        let tagB = Tag(name: "WORK", nameNormalized: "work")
        context.insert(tagA)
        context.insert(tagB)
        episode.tags = [tagA, tagB, tagB]

        let episodeToDelete = Episode(date: Date(timeIntervalSince1970: 2), title: "E2")
        context.insert(episodeToDelete)
        let orphanCandidate = UnlockLog(
            talkedAt: Date(timeIntervalSince1970: 3),
            reaction: "ok",
            memo: "",
            episode: episodeToDelete
        )
        context.insert(orphanCandidate)
        context.delete(episodeToDelete)
        try context.save()

        let service = CloudSyncDataPreparationService(
            modelContext: context,
            settingsRepository: settings
        )
        service.prepareIfNeeded()

        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 1)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        let refreshed = try XCTUnwrap(episodes.first(where: { $0.id == episode.id }))
        XCTAssertEqual(refreshed.tags.count, 1)

        let unlockLogs = try context.fetch(FetchDescriptor<UnlockLog>())
        XCTAssertEqual(unlockLogs.count, 0)

        XCTAssertTrue(settings.bool(for: .cloudSyncMigrationPrepared))
        XCTAssertFalse(settings.bool(for: .cloudSyncRuntimeDisabled))
    }

    func testPrepareIfNeededIsIdempotentOnceMarkedPrepared() throws {
        let container = TestModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = InMemoryPreparationSettingsRepository()

        let episode = Episode(date: Date(timeIntervalSince1970: 1), title: "E1")
        context.insert(episode)
        let tagA = Tag(name: "Alpha", nameNormalized: "alpha")
        let tagB = Tag(name: "ALPHA", nameNormalized: "alpha")
        context.insert(tagA)
        context.insert(tagB)
        episode.tags = [tagA, tagB]
        try context.save()

        let service = CloudSyncDataPreparationService(
            modelContext: context,
            settingsRepository: settings
        )
        service.prepareIfNeeded()
        service.prepareIfNeeded()

        let tags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 1)
        XCTAssertTrue(settings.bool(for: .cloudSyncMigrationPrepared))
    }
}

private final class InMemoryPreparationSettingsRepository: SettingsRepository {
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
