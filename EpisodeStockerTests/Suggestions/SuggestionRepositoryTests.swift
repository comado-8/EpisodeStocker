import XCTest
@testable import EpisodeStocker

final class SuggestionRepositoryTests: XCTestCase {
    func testFetchRespectsFieldTypeQueryAndDeletedFlag() {
        let now = Date()
        let repo = InMemorySuggestionRepository(
            seed: [
                Suggestion(id: UUID(), fieldType: "人物", value: "田中さん", usageCount: 2, lastUsedAt: now, isDeleted: false),
                Suggestion(id: UUID(), fieldType: "人物", value: "削除済み", usageCount: 1, lastUsedAt: now, isDeleted: true),
                Suggestion(id: UUID(), fieldType: "企画名", value: "朝の番組", usageCount: 3, lastUsedAt: now, isDeleted: false)
            ]
        )

        let personsOnly = repo.fetch(fieldType: "人物", query: nil, includeDeleted: false)
        XCTAssertEqual(personsOnly.count, 1)
        XCTAssertEqual(personsOnly.first?.value, "田中さん")

        let withDeleted = repo.fetch(fieldType: "人物", query: nil, includeDeleted: true)
        XCTAssertEqual(withDeleted.count, 2)

        let queried = repo.fetch(fieldType: "人物", query: "田", includeDeleted: false)
        XCTAssertEqual(queried.count, 1)
        XCTAssertEqual(queried.first?.value, "田中さん")
    }

    func testFetchSortsByLastUsedThenUsageThenValue() {
        let now = Date()
        let old = now.addingTimeInterval(-3600)

        let repo = InMemorySuggestionRepository(
            seed: [
                Suggestion(id: UUID(), fieldType: "人物", value: "OlderHighUsage", usageCount: 99, lastUsedAt: old, isDeleted: false),
                Suggestion(id: UUID(), fieldType: "人物", value: "Beta", usageCount: 2, lastUsedAt: now, isDeleted: false),
                Suggestion(id: UUID(), fieldType: "人物", value: "Alpha", usageCount: 2, lastUsedAt: now, isDeleted: false),
                Suggestion(id: UUID(), fieldType: "人物", value: "Gamma", usageCount: 1, lastUsedAt: now, isDeleted: false)
            ]
        )

        let fetched = repo.fetch(fieldType: "人物", query: nil, includeDeleted: false)
        XCTAssertEqual(fetched.map(\.value), ["Alpha", "Beta", "Gamma", "OlderHighUsage"])
    }

    func testUpsertCreatesBumpsAndRestoresDeletedItem() {
        let id = UUID()
        let repo = InMemorySuggestionRepository(
            seed: [
                Suggestion(id: id, fieldType: "人物", value: "田中さん", usageCount: 1, lastUsedAt: Date(timeIntervalSince1970: 1), isDeleted: true)
            ]
        )

        repo.upsert(fieldType: "人物", value: "  田中さん ")

        Eventually.assertEventually {
            guard let item = repo.fetch(fieldType: "人物", query: "田中", includeDeleted: true).first else {
                return false
            }
            return item.id == id && item.usageCount == 2 && item.isDeleted == false
        }

        repo.upsert(fieldType: "人物", value: "鈴木さん")

        Eventually.assertEventually {
            let fetched = repo.fetch(fieldType: "人物", query: nil, includeDeleted: false)
            return fetched.contains(where: { $0.value == "鈴木さん" })
        }
    }

    func testSoftDeleteRestoreAndBumpUsage() {
        let id = UUID()
        let oldDate = Date(timeIntervalSince1970: 1)
        let repo = InMemorySuggestionRepository(
            seed: [
                Suggestion(id: id, fieldType: "企画名", value: "朝の番組", usageCount: 1, lastUsedAt: oldDate, isDeleted: false)
            ]
        )

        repo.softDelete(id: id)
        Eventually.assertEventually {
            repo.fetch(fieldType: "企画名", query: nil, includeDeleted: false).isEmpty
        }

        repo.restore(id: id)
        Eventually.assertEventually {
            repo.fetch(fieldType: "企画名", query: nil, includeDeleted: false).count == 1
        }

        repo.bumpUsage(id: id)
        Eventually.assertEventually {
            guard let item = repo.fetch(fieldType: "企画名", query: nil, includeDeleted: false).first else {
                return false
            }
            return item.usageCount == 2 && item.lastUsedAt > oldDate
        }
    }
}
