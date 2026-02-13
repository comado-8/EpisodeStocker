import SwiftData
import XCTest
@testable import EpisodeStocker

@MainActor
final class PersistenceUpsertTests: XCTestCase {
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

    func testUpsertTagReusesExistingAndRevivesDeleted() throws {
        let first = try XCTUnwrap(context.upsertTag(name: " #仕事 "))
        first.isSoftDeleted = true
        first.deletedAt = Date(timeIntervalSince1970: 1)
        try context.save()

        let revived = try XCTUnwrap(context.upsertTag(name: "仕事"))

        XCTAssertEqual(revived.id, first.id)
        XCTAssertFalse(revived.isSoftDeleted)
        XCTAssertNil(revived.deletedAt)
        XCTAssertEqual(revived.name, "仕事")
        XCTAssertEqual(revived.nameNormalized, "仕事")
    }

    func testUpsertTagsDeduplicatesNormalizedValues() throws {
        let tags = context.upsertTags(from: ["#Alpha", " alpha ", "ALPHA", "#Beta", "  "])
        XCTAssertEqual(tags.count, 2)

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(Set(fetched.map(\.nameNormalized)), Set(["alpha", "beta"]))
    }

    func testUpsertEntitiesReuseByNormalizedName() {
        let person1 = context.upsertPerson(name: " Alice ")
        let person2 = context.upsertPerson(name: "alice")
        XCTAssertEqual(person1?.id, person2?.id)

        let project1 = context.upsertProject(name: " Morning Show ")
        let project2 = context.upsertProject(name: "morning show")
        XCTAssertEqual(project1?.id, project2?.id)

        let emotion1 = context.upsertEmotion(name: "Happy")
        let emotion2 = context.upsertEmotion(name: "happy")
        XCTAssertEqual(emotion1?.id, emotion2?.id)

        let place1 = context.upsertPlace(name: "Shibuya")
        let place2 = context.upsertPlace(name: "shibuya")
        XCTAssertEqual(place1?.id, place2?.id)
    }
}
