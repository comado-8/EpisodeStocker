import SwiftData
import XCTest
@testable import EpisodeStocker

@MainActor
final class HomeSearchQueryEngineTests: XCTestCase {
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

    func testFreeTextMatchesTitleAndBody() {
        let titleHit = makeEpisode(title: "Gmail風検索", body: "本文")
        _ = makeEpisode(title: "別タイトル", body: "body hit keyword")

        var search = HomeSearchQueryState()
        search.freeText = "gmail"

        let result = filter(search: search, statusFilter: .all)

        XCTAssertEqual(result.map(\.id), [titleHit.id])

        search.freeText = "keyword"
        let bodyResult = filter(search: search, statusFilter: .all)
        XCTAssertEqual(bodyResult.count, 1)
    }

    func testTagSearchNormalizesLeadingHash() {
        let tagged = makeEpisode(title: "Tag target", body: "", tags: ["#仕事"])
        _ = makeEpisode(title: "Other", body: "", tags: ["#雑談"])

        let token = HomeSearchFilterToken(field: .tag, value: "#仕事")!
        let search = HomeSearchQueryState(freeText: "", tokens: [token], activeField: nil)
        let result = filter(search: search, statusFilter: .all)

        XCTAssertEqual(result.map(\.id), [tagged.id])
    }

    func testSameFieldMultipleTokensUseOr() {
        let first = makeEpisode(title: "A", body: "", tags: ["#仕事"])
        let second = makeEpisode(title: "B", body: "", tags: ["#学び"])
        _ = makeEpisode(title: "C", body: "", tags: ["#雑談"])

        let tokens = [
            HomeSearchFilterToken(field: .tag, value: "仕事")!,
            HomeSearchFilterToken(field: .tag, value: "学び")!
        ]
        let search = HomeSearchQueryState(freeText: "", tokens: tokens, activeField: nil)

        let result = filter(search: search, statusFilter: .all)

        XCTAssertEqual(Set(result.map(\.id)), Set([first.id, second.id]))
    }

    func testDifferentFieldsUseAnd() {
        let both = Episode(
            date: Date(),
            title: "A",
            body: "",
            tags: [Tag(name: "仕事", nameNormalized: "仕事")],
            persons: [Person(name: "Alice", nameNormalized: "alice")]
        )
        let tagOnly = Episode(
            date: Date(),
            title: "B",
            body: "",
            tags: [Tag(name: "仕事", nameNormalized: "仕事")],
            persons: [Person(name: "Bob", nameNormalized: "bob")]
        )
        let personOnly = Episode(
            date: Date(),
            title: "C",
            body: "",
            tags: [Tag(name: "学び", nameNormalized: "学び")],
            persons: [Person(name: "Alice", nameNormalized: "alice")]
        )

        let tokens = [
            HomeSearchFilterToken(field: .tag, value: "仕事")!,
            HomeSearchFilterToken(field: .person, value: "Ali")!
        ]
        let search = HomeSearchQueryState(freeText: "", tokens: tokens, activeField: nil)
        let result = [both, tagOnly, personOnly].filter { episode in
            HomeSearchQueryEngine.matches(
                episode: episode,
                statusFilter: .all,
                search: search
            )
        }

        XCTAssertEqual(result.map(\.id), [both.id])
    }

    func testFreeTextAndStructuredAreCombinedWithAnd() {
        let match = makeEpisode(
            title: "検索改善メモ",
            body: "Gmail 風のUI",
            tags: ["#仕事"]
        )
        _ = makeEpisode(title: "検索改善メモ", body: "Gmail 風", tags: ["#雑談"])

        let token = HomeSearchFilterToken(field: .tag, value: "仕事")!
        let search = HomeSearchQueryState(
            freeText: "gmail",
            tokens: [token],
            activeField: nil
        )

        let result = filter(search: search, statusFilter: .all)

        XCTAssertEqual(result.map(\.id), [match.id])
    }

    func testStatusFilterStillApplies() {
        let unlocked = makeEpisode(
            title: "Unlocked",
            body: "",
            unlockDate: Date().addingTimeInterval(-60),
            tags: ["#仕事"]
        )
        _ = makeEpisode(
            title: "Locked",
            body: "",
            unlockDate: Date().addingTimeInterval(60 * 60),
            tags: ["#仕事"]
        )

        let token = HomeSearchFilterToken(field: .tag, value: "仕事")!
        let search = HomeSearchQueryState(freeText: "", tokens: [token], activeField: nil)

        let okResult = filter(search: search, statusFilter: .ok)

        XCTAssertEqual(okResult.map(\.id), [unlocked.id])
    }

    func testLockedStatusFilterStillApplies() {
        _ = makeEpisode(
            title: "Unlocked",
            body: "",
            unlockDate: Date().addingTimeInterval(-60),
            tags: ["#仕事"]
        )
        let locked = makeEpisode(
            title: "Locked",
            body: "",
            unlockDate: Date().addingTimeInterval(60 * 60),
            tags: ["#仕事"]
        )

        let token = HomeSearchFilterToken(field: .tag, value: "仕事")!
        let search = HomeSearchQueryState(freeText: "", tokens: [token], activeField: nil)

        let lockedResult = filter(search: search, statusFilter: .locked)

        XCTAssertEqual(lockedResult.map(\.id), [locked.id])
    }

    func testStructuredSearchMatchesProjectEmotionAndPlace() {
        let match = Episode(
            date: Date(),
            title: "構造化一致",
            body: "",
            projects: [Project(name: "朝番組企画", nameNormalized: "朝番組企画")],
            emotions: [Emotion(name: "ワクワク", nameNormalized: "ワクワク")],
            places: [Place(name: "渋谷スタジオ", nameNormalized: "渋谷スタジオ")]
        )
        let partial = Episode(
            date: Date(),
            title: "企画のみ",
            body: "",
            projects: [Project(name: "朝番組企画", nameNormalized: "朝番組企画")],
            emotions: [Emotion(name: "落ち着き", nameNormalized: "落ち着き")],
            places: [Place(name: "赤坂", nameNormalized: "赤坂")]
        )

        let tokens = [
            HomeSearchFilterToken(field: .project, value: "朝番組")!,
            HomeSearchFilterToken(field: .emotion, value: "ワク")!,
            HomeSearchFilterToken(field: .place, value: "渋谷")!
        ]
        let search = HomeSearchQueryState(freeText: "", tokens: tokens, activeField: nil)

        let result = [match, partial].filter { episode in
            HomeSearchQueryEngine.matches(
                episode: episode,
                statusFilter: .all,
                search: search
            )
        }

        XCTAssertEqual(result.map(\.id), [match.id])
    }

    func testFieldAndSuggestionPresentationProperties() {
        for field in HomeSearchField.allCases {
            XCTAssertFalse(field.symbolName.isEmpty)
        }

        let selectItem = HomeSearchSuggestionItem(kind: .selectField(.emotion))
        XCTAssertEqual(selectItem.title, "感情で絞り込む")
        XCTAssertEqual(selectItem.subtitle, "次の入力を感情として扱います")
        XCTAssertEqual(selectItem.symbolName, HomeSearchField.emotion.symbolName)

        let valueItem = HomeSearchSuggestionItem(kind: .value(field: .project, value: "朝番組"))
        XCTAssertEqual(valueItem.title, "企画名: 朝番組")
        XCTAssertEqual(valueItem.subtitle, "候補から追加")
        XCTAssertEqual(valueItem.symbolName, HomeSearchField.project.symbolName)
    }

    func testSuggestionsRespectFieldOrderAndMaxValuesPerField() {
        _ = makeEpisode(title: "1", body: "", persons: ["Alice"])
        _ = makeEpisode(title: "2", body: "", persons: ["Ami"])
        _ = makeEpisode(title: "3", body: "", persons: ["Aoi"])
        _ = makeEpisode(title: "4", body: "", persons: ["Abe"])
        _ = makeEpisode(title: "5", body: "", tags: ["#alpha"])

        var search = HomeSearchQueryState()
        search.freeText = "tag"

        let items = HomeSearchQueryEngine.suggestions(for: search, episodes: fetchEpisodes())
        guard let first = items.first else {
            return XCTFail("No suggestions were returned")
        }

        XCTAssertEqual(first.kind, .selectField(.tag))

        search = HomeSearchQueryState(freeText: "a", tokens: [], activeField: .person)
        let personItems = HomeSearchQueryEngine.suggestions(for: search, episodes: fetchEpisodes())
        let personValueItems = personItems.filter {
            if case .value(field: .person, value: _) = $0.kind {
                return true
            }
            return false
        }

        XCTAssertLessThanOrEqual(personValueItems.count, 3)
    }

    func testSuggestionsAreEmptyWhenNoFieldValueMatches() {
        _ = makeEpisode(title: "1", body: "", persons: ["Alice"])

        var search = HomeSearchQueryState()
        search.freeText = "nohitvalue"

        let items = HomeSearchQueryEngine.suggestions(for: search, episodes: fetchEpisodes())
        XCTAssertTrue(items.isEmpty)

        search = HomeSearchQueryState(freeText: "nohitvalue", tokens: [], activeField: .tag)
        let activeFieldItems = HomeSearchQueryEngine.suggestions(for: search, episodes: fetchEpisodes())
        XCTAssertTrue(activeFieldItems.isEmpty)
    }

    func testActiveFieldSuggestionsDoNotIncludeRedundantFieldSelector() {
        _ = makeEpisode(title: "1", body: "", emotions: ["楽しかった"])

        let search = HomeSearchQueryState(freeText: "", tokens: [], activeField: .emotion)
        let items = HomeSearchQueryEngine.suggestions(for: search, episodes: fetchEpisodes())
        let hasFieldSelector = items.contains {
            if case .selectField(.emotion) = $0.kind {
                return true
            }
            return false
        }

        XCTAssertFalse(hasFieldSelector)
    }
}

@MainActor
private extension HomeSearchQueryEngineTests {
    func makeEpisode(
        title: String,
        body: String,
        unlockDate: Date? = nil,
        tags: [String] = [],
        persons: [String] = [],
        projects: [String] = [],
        emotions: [String] = [],
        place: String? = nil
    ) -> Episode {
        context.createEpisode(
            title: title,
            body: body,
            date: Date(),
            unlockDate: unlockDate,
            type: nil,
            tags: tags,
            persons: persons,
            projects: projects,
            emotions: emotions,
            place: place
        )
    }

    func fetchEpisodes() -> [Episode] {
        let descriptor = FetchDescriptor<Episode>(
            sortBy: [SortDescriptor(\Episode.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func filter(search: HomeSearchQueryState, statusFilter: HomeStatusFilter) -> [Episode] {
        fetchEpisodes().filter { episode in
            HomeSearchQueryEngine.matches(
                episode: episode,
                statusFilter: statusFilter,
                search: search
            )
        }
    }
}
