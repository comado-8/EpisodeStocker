import XCTest
@testable import EpisodeStocker

@MainActor
final class SuggestionManagerViewModelTests: XCTestCase {
    func testInitFetchesSuggestionsForFieldType() {
        let repo = FakeSuggestionRepository(
            items: [
                Suggestion(id: UUID(), fieldType: "人物", value: "田中さん", usageCount: 1, lastUsedAt: Date(), isDeleted: false),
                Suggestion(id: UUID(), fieldType: "企画名", value: "朝番組", usageCount: 1, lastUsedAt: Date(), isDeleted: false)
            ]
        )

        let vm = SuggestionManagerViewModel(repository: repo, fieldType: "人物")

        XCTAssertEqual(vm.suggestions.count, 1)
        XCTAssertEqual(vm.suggestions.first?.value, "田中さん")
    }

    func testQueryDidSetRefreshesSuggestions() {
        let repo = FakeSuggestionRepository(
            items: [
                Suggestion(id: UUID(), fieldType: "人物", value: "田中さん", usageCount: 1, lastUsedAt: Date(), isDeleted: false),
                Suggestion(id: UUID(), fieldType: "人物", value: "佐藤さん", usageCount: 1, lastUsedAt: Date(), isDeleted: false)
            ]
        )

        let vm = SuggestionManagerViewModel(repository: repo, fieldType: "人物")
        vm.query = "佐"

        XCTAssertEqual(vm.suggestions.count, 1)
        XCTAssertEqual(vm.suggestions.first?.value, "佐藤さん")
    }

    func testIncludeDeletedDidSetRefreshesSuggestions() {
        let repo = FakeSuggestionRepository(
            items: [
                Suggestion(id: UUID(), fieldType: "人物", value: "表示対象", usageCount: 1, lastUsedAt: Date(), isDeleted: false),
                Suggestion(id: UUID(), fieldType: "人物", value: "削除済み", usageCount: 1, lastUsedAt: Date(), isDeleted: true)
            ]
        )

        let vm = SuggestionManagerViewModel(repository: repo, fieldType: "人物")
        XCTAssertEqual(vm.suggestions.count, 1)

        vm.includeDeleted = true
        XCTAssertEqual(vm.suggestions.count, 2)
    }

    func testSoftDeleteAndUndoDelete() {
        let targetId = UUID()
        let repo = FakeSuggestionRepository(
            items: [
                Suggestion(id: targetId, fieldType: "人物", value: "対象", usageCount: 1, lastUsedAt: Date(), isDeleted: false)
            ]
        )

        let vm = SuggestionManagerViewModel(repository: repo, fieldType: "人物")
        vm.softDelete(targetId)
        XCTAssertTrue(vm.suggestions.isEmpty)

        vm.undoDelete()
        XCTAssertEqual(vm.suggestions.count, 1)
        XCTAssertEqual(vm.suggestions.first?.id, targetId)
    }
}

private final class FakeSuggestionRepository: SuggestionRepository {
    private var items: [Suggestion]

    init(items: [Suggestion]) {
        self.items = items
    }

    func fetch(fieldType: String, query: String?, includeDeleted: Bool) -> [Suggestion] {
        let trimmedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines)
        return items
            .filter { item in
                guard item.fieldType == fieldType else { return false }
                if !includeDeleted && item.isDeleted { return false }
                if let q = trimmedQuery, !q.isEmpty {
                    return item.value.localizedCaseInsensitiveContains(q)
                }
                return true
            }
            .sorted { $0.value < $1.value }
    }

    func softDelete(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isDeleted = true
    }

    func restore(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isDeleted = false
    }

    func bumpUsage(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].usageCount += 1
        items[idx].lastUsedAt = Date()
    }

    func upsert(fieldType: String, value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let idx = items.firstIndex(where: { $0.fieldType == fieldType && $0.value.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            items[idx].usageCount += 1
            items[idx].lastUsedAt = Date()
            items[idx].isDeleted = false
            return
        }

        items.append(
            Suggestion(
                id: UUID(),
                fieldType: fieldType,
                value: trimmed,
                usageCount: 1,
                lastUsedAt: Date(),
                isDeleted: false
            )
        )
    }
}
