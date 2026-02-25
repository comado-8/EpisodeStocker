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

    func testUpsertTagReusesLegacyFullwidthHashTag() throws {
        let legacy = Tag(name: "＃仕事", nameNormalized: "＃仕事")
        context.insert(legacy)
        try context.save()

        let reused = try XCTUnwrap(context.upsertTag(name: "仕事"))

        XCTAssertEqual(reused.id, legacy.id)
        XCTAssertEqual(reused.name, "仕事")
        XCTAssertEqual(reused.nameNormalized, "仕事")
    }

    func testUpsertTagCompactsWhitespaces() throws {
        let tag = try XCTUnwrap(context.upsertTag(name: " # T a　g Name "))
        XCTAssertEqual(tag.name, "tagname")
        XCTAssertEqual(tag.nameNormalized, "tagname")
    }

    func testUpsertTagReturnsNilForEmptyCandidate() {
        XCTAssertNil(context.upsertTag(name: "   "))
        XCTAssertNil(context.upsertTag(name: "###"))
    }

    func testUpsertTagCanonicalizesEnglishCaseToLowercase() throws {
        let first = try XCTUnwrap(context.upsertTag(name: "#TaG"))
        let second = try XCTUnwrap(context.upsertTag(name: "#TAG"))

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(second.name, "tag")
        XCTAssertEqual(second.nameNormalized, "tag")
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

    func testUpsertEntitiesReviveDeletedRecords() throws {
        let person = try XCTUnwrap(context.upsertPerson(name: "Alice"))
        person.isSoftDeleted = true
        person.deletedAt = Date(timeIntervalSince1970: 10)

        let project = try XCTUnwrap(context.upsertProject(name: "Morning Show"))
        project.isSoftDeleted = true
        project.deletedAt = Date(timeIntervalSince1970: 10)

        let emotion = try XCTUnwrap(context.upsertEmotion(name: "Happy"))
        emotion.isSoftDeleted = true
        emotion.deletedAt = Date(timeIntervalSince1970: 10)

        let place = try XCTUnwrap(context.upsertPlace(name: "Shibuya"))
        place.isSoftDeleted = true
        place.deletedAt = Date(timeIntervalSince1970: 10)
        try context.save()

        let revivedPerson = try XCTUnwrap(context.upsertPerson(name: " alice "))
        let revivedProject = try XCTUnwrap(context.upsertProject(name: "morning show"))
        let revivedEmotion = try XCTUnwrap(context.upsertEmotion(name: "happy"))
        let revivedPlace = try XCTUnwrap(context.upsertPlace(name: "shibuya"))

        XCTAssertEqual(revivedPerson.id, person.id)
        XCTAssertEqual(revivedProject.id, project.id)
        XCTAssertEqual(revivedEmotion.id, emotion.id)
        XCTAssertEqual(revivedPlace.id, place.id)

        XCTAssertFalse(revivedPerson.isSoftDeleted)
        XCTAssertFalse(revivedProject.isSoftDeleted)
        XCTAssertFalse(revivedEmotion.isSoftDeleted)
        XCTAssertFalse(revivedPlace.isSoftDeleted)
        XCTAssertNil(revivedPerson.deletedAt)
        XCTAssertNil(revivedProject.deletedAt)
        XCTAssertNil(revivedEmotion.deletedAt)
        XCTAssertNil(revivedPlace.deletedAt)
    }

    func testUpsertCollectionHelpersSkipEmptyAndDeduplicate() throws {
        let persons = context.upsertPersons(from: [" Alice ", "alice", " ", "Bob"])
        let projects = context.upsertProjects(from: ["Morning", "morning", "", "Night"])
        let emotions = context.upsertEmotions(from: ["Happy", "happy", " ", "Sad"])
        let places = context.upsertPlaces(from: ["Shibuya", "shibuya", "", "Studio"])

        XCTAssertEqual(persons.count, 2)
        XCTAssertEqual(projects.count, 2)
        XCTAssertEqual(emotions.count, 2)
        XCTAssertEqual(places.count, 2)

        let fetchedPersons = try context.fetch(FetchDescriptor<Person>())
        let fetchedProjects = try context.fetch(FetchDescriptor<Project>())
        let fetchedEmotions = try context.fetch(FetchDescriptor<Emotion>())
        let fetchedPlaces = try context.fetch(FetchDescriptor<Place>())

        XCTAssertEqual(fetchedPersons.count, 2)
        XCTAssertEqual(fetchedProjects.count, 2)
        XCTAssertEqual(fetchedEmotions.count, 2)
        XCTAssertEqual(fetchedPlaces.count, 2)
    }
}
