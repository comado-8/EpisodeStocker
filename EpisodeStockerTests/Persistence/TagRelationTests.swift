import SwiftData
import XCTest
@testable import EpisodeStocker

@MainActor
final class TagRelationTests: XCTestCase {
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

    func testSoftDeleteTagUnlinksOnlyActiveEpisodes() {
        let episode1 = context.createEpisode(
            title: "E1",
            body: "Body",
            date: Date(),
            unlockDate: nil,
            type: nil,
            tags: ["#Topic"],
            persons: [],
            projects: [],
            emotions: [],
            place: nil
        )
        let episode2 = context.createEpisode(
            title: "E2",
            body: "Body",
            date: Date(),
            unlockDate: nil,
            type: nil,
            tags: ["#Topic"],
            persons: [],
            projects: [],
            emotions: [],
            place: nil
        )
        context.softDeleteEpisode(episode2)

        let tag = try! XCTUnwrap(episode1.tags.first)
        let affected = context.softDeleteTag(tag)

        XCTAssertEqual(Set(affected), Set([episode1.id]))
        XCTAssertFalse(episode1.tags.contains(where: { $0.id == tag.id }))
        XCTAssertTrue(episode2.tags.contains(where: { $0.id == tag.id }))
        XCTAssertTrue(tag.isSoftDeleted)
    }

    func testRestoreTagRelinksOnlyNonDeletedEpisodes() {
        let episode1 = context.createEpisode(
            title: "E1",
            body: "Body",
            date: Date(),
            unlockDate: nil,
            type: nil,
            tags: ["#Topic"],
            persons: [],
            projects: [],
            emotions: [],
            place: nil
        )
        let episode2 = context.createEpisode(
            title: "E2",
            body: "Body",
            date: Date(),
            unlockDate: nil,
            type: nil,
            tags: ["#Topic"],
            persons: [],
            projects: [],
            emotions: [],
            place: nil
        )

        let tag = try! XCTUnwrap(episode1.tags.first)
        let affected = context.softDeleteTag(tag)
        context.softDeleteEpisode(episode2)

        context.restoreTag(tag, episodeIds: affected)

        XCTAssertFalse(tag.isSoftDeleted)
        XCTAssertTrue(episode1.tags.contains(where: { $0.id == tag.id }))
        XCTAssertFalse(episode2.tags.contains(where: { $0.id == tag.id }))
    }
}
