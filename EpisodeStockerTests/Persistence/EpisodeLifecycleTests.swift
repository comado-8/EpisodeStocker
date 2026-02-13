import SwiftData
import XCTest
@testable import EpisodeStocker

@MainActor
final class EpisodeLifecycleTests: XCTestCase {
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

    func testCreateEpisodePersistsCoreFieldsAndRelations() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let unlockDate = date.addingTimeInterval(3600)

        let episode = context.createEpisode(
            title: "収録前の小ネタ",
            body: "本文",
            date: date,
            unlockDate: unlockDate,
            type: "会話ネタ",
            tags: ["#TagA", "taga", "#TagB"],
            persons: ["Alice", "alice", "Bob"],
            projects: ["Morning"],
            emotions: ["Happy", "happy"],
            place: "Tokyo"
        )

        XCTAssertEqual(episode.title, "収録前の小ネタ")
        XCTAssertEqual(episode.body, "本文")
        XCTAssertEqual(episode.date, date)
        XCTAssertEqual(episode.unlockDate, unlockDate)
        XCTAssertEqual(episode.type, "会話ネタ")
        XCTAssertEqual(episode.tags.count, 2)
        XCTAssertEqual(episode.persons.count, 2)
        XCTAssertEqual(episode.projects.count, 1)
        XCTAssertEqual(episode.emotions.count, 1)
        XCTAssertEqual(episode.places.count, 1)

        let fetched = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(fetched.count, 1)
    }

    func testUpdateEpisodeUpdatesFieldsRelationsAndTimestamp() {
        let episode = context.createEpisode(
            title: "Old",
            body: "OldBody",
            date: Date(timeIntervalSince1970: 100),
            unlockDate: nil,
            type: "会話ネタ",
            tags: ["#old"],
            persons: ["Old Person"],
            projects: ["Old Project"],
            emotions: ["Old Emotion"],
            place: "Old Place"
        )

        episode.updatedAt = Date(timeIntervalSince1970: 1)

        context.updateEpisode(
            episode,
            title: "New",
            body: nil,
            date: Date(timeIntervalSince1970: 200),
            unlockDate: Date(timeIntervalSince1970: 300),
            type: nil,
            tags: ["#new"],
            persons: ["New Person"],
            projects: ["New Project"],
            emotions: ["New Emotion1", "New Emotion2"],
            place: nil
        )

        XCTAssertEqual(episode.title, "New")
        XCTAssertNil(episode.body)
        XCTAssertEqual(episode.tags.map(\.nameNormalized), ["new"])
        XCTAssertEqual(episode.persons.map(\.nameNormalized), ["new person"])
        XCTAssertEqual(episode.projects.map(\.nameNormalized), ["new project"])
        XCTAssertEqual(episode.emotions.count, 2)
        XCTAssertTrue(episode.places.isEmpty)
        XCTAssertGreaterThan(episode.updatedAt, Date(timeIntervalSince1970: 1))
    }

    func testSoftDeleteEpisodeAlsoSoftDeletesUnlockLogs() {
        let episode = context.createEpisode(
            title: "Delete Target",
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
            projectNameText: "番組",
            reaction: ReleaseLogOutcome.hit.rawValue,
            memo: "良かった"
        )

        context.softDeleteEpisode(episode)

        XCTAssertTrue(episode.isSoftDeleted)
        XCTAssertNotNil(episode.deletedAt)
        XCTAssertTrue(log.isSoftDeleted)
        XCTAssertNotNil(log.deletedAt)
    }
}
