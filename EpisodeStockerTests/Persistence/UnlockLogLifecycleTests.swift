import SwiftData
import XCTest
@testable import EpisodeStocker

@MainActor
final class UnlockLogLifecycleTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = TestModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    func testCreateUnlockLogLinksToEpisode() throws {
        let episode = context.createEpisode(
            title: "Episode",
            body: "Body",
            date: Date(),
            unlockDate: nil,
            type: nil,
            tags: [],
            persons: [],
            projects: [],
            emotions: [],
            place: nil
        )

        let log = context.createUnlockLog(
            episode: episode,
            talkedAt: Date(timeIntervalSince1970: 500),
            mediaPublicAt: Date(timeIntervalSince1970: 800),
            mediaType: ReleaseLogMediaPreset.tv.rawValue,
            projectNameText: "朝番組",
            reaction: ReleaseLogOutcome.soSo.rawValue,
            memo: "メモ"
        )

        XCTAssertEqual(log.episode.id, episode.id)
        XCTAssertTrue(episode.unlockLogs.contains(where: { $0.id == log.id }))
        XCTAssertEqual(log.mediaType, ReleaseLogMediaPreset.tv.rawValue)

        let fetched = try context.fetch(FetchDescriptor<UnlockLog>())
        XCTAssertEqual(fetched.count, 1)
    }

    func testUpdateUnlockLogUpdatesFieldsAndTimestamp() {
        let episode = context.createEpisode(
            title: "Episode",
            body: "Body",
            date: Date(),
            unlockDate: nil,
            type: nil,
            tags: [],
            persons: [],
            projects: [],
            emotions: [],
            place: nil
        )

        let log = context.createUnlockLog(
            episode: episode,
            talkedAt: Date(timeIntervalSince1970: 100),
            mediaPublicAt: nil,
            mediaType: nil,
            projectNameText: "Old",
            reaction: ReleaseLogOutcome.hit.rawValue,
            memo: "Old memo"
        )

        log.updatedAt = Date(timeIntervalSince1970: 1)

        context.updateUnlockLog(
            log,
            talkedAt: Date(timeIntervalSince1970: 200),
            mediaPublicAt: Date(timeIntervalSince1970: 300),
            mediaType: ReleaseLogMediaPreset.streaming.rawValue,
            projectNameText: "New",
            reaction: ReleaseLogOutcome.shelved.rawValue,
            memo: "New memo"
        )

        XCTAssertEqual(log.talkedAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(log.mediaPublicAt, Date(timeIntervalSince1970: 300))
        XCTAssertEqual(log.mediaType, ReleaseLogMediaPreset.streaming.rawValue)
        XCTAssertEqual(log.projectNameText, "New")
        XCTAssertEqual(log.reaction, ReleaseLogOutcome.shelved.rawValue)
        XCTAssertEqual(log.memo, "New memo")
        XCTAssertGreaterThan(log.updatedAt, Date(timeIntervalSince1970: 1))
    }

    func testSoftDeleteUnlockLogMarksFlags() {
        let episode = context.createEpisode(
            title: "Episode",
            body: "Body",
            date: Date(),
            unlockDate: nil,
            type: nil,
            tags: [],
            persons: [],
            projects: [],
            emotions: [],
            place: nil
        )

        let log = context.createUnlockLog(
            episode: episode,
            talkedAt: Date(),
            mediaPublicAt: nil,
            mediaType: nil,
            projectNameText: "番組",
            reaction: ReleaseLogOutcome.hit.rawValue,
            memo: "memo"
        )

        context.softDeleteUnlockLog(log)

        XCTAssertTrue(log.isSoftDeleted)
        XCTAssertNotNil(log.deletedAt)
    }
}
