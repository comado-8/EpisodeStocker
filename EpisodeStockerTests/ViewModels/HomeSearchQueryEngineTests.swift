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
        let bodyHit = makeEpisode(title: "別タイトル", body: "body hit keyword")

        var search = HomeSearchQueryState()
        search.freeText = "gmail"

        let result = filter(search: search, statusFilter: .all)

        XCTAssertEqual(result.map(\.id), [titleHit.id])

        search.freeText = "keyword"
        let bodyResult = filter(search: search, statusFilter: .all)
        XCTAssertEqual(bodyResult.map(\.id), [bodyHit.id])
    }

    func testTagSearchNormalizesLeadingHash() {
        let tagged = makeEpisode(title: "Tag target", body: "", tags: ["#仕事"])
        _ = makeEpisode(title: "Other", body: "", tags: ["#雑談"])

        let token = HomeSearchFilterToken(field: .tag, value: "仕事")!
        let search = HomeSearchQueryState(freeText: "", tokens: [token], activeField: nil)
        let result = filter(search: search, statusFilter: .all)

        XCTAssertEqual(result.map(\.id), [tagged.id])
    }

    func testTagSearchNormalizesLeadingFullwidthHash() {
        let tagged = makeEpisode(title: "Tag target", body: "", tags: ["#仕事"])
        _ = makeEpisode(title: "Other", body: "", tags: ["#雑談"])

        let token = HomeSearchFilterToken(field: .tag, value: "＃仕事")!
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

        let valueItem = HomeSearchSuggestionItem(kind: .value(field: .project, value: "朝番組"))
        XCTAssertEqual(valueItem.title, "企画名: 朝番組")
        XCTAssertEqual(valueItem.subtitle, "候補から追加")
        XCTAssertEqual(valueItem.symbolName, HomeSearchField.project.symbolName)
    }

    func testSuggestionsRespectFieldOrderAndMaxValuesPerField() throws {
        _ = makeEpisode(title: "1", body: "", persons: ["Alice"])
        _ = makeEpisode(title: "2", body: "", persons: ["Ami"])
        _ = makeEpisode(title: "3", body: "", persons: ["Aoi"])
        _ = makeEpisode(title: "4", body: "", persons: ["Abe"])
        _ = makeEpisode(title: "5", body: "", tags: ["#alpha"])

        var search = HomeSearchQueryState()
        search.freeText = "a"

        let items = HomeSearchQueryEngine.suggestions(for: search, episodes: fetchEpisodes())
        let first = try XCTUnwrap(items.first)

        XCTAssertEqual(first.kind, .value(field: .tag, value: "alpha"))

        search = HomeSearchQueryState(freeText: "a", tokens: [], activeField: .person)
        let personItems = HomeSearchQueryEngine.suggestions(for: search, episodes: fetchEpisodes())
        let personValueItems = personItems.filter {
            if case .value(field: .person, value: _) = $0.kind {
                return true
            }
            return false
        }

        XCTAssertEqual(personValueItems.count, 3)
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

    func testSuggestionsDoNotOfferFieldSelectorItems() {
        _ = makeEpisode(title: "1", body: "", tags: ["#Tag"])

        let search = HomeSearchQueryState(freeText: "a", tokens: [], activeField: nil)
        let items = HomeSearchQueryEngine.suggestions(for: search, episodes: fetchEpisodes())

        let hasFieldSelector = items.contains {
            if case .selectField = $0.kind {
                return true
            }
            return false
        }

        XCTAssertFalse(hasFieldSelector)
    }

    func testSuggestionsMergeCountsAcrossCaseVariants() throws {
        let alphaUpper = Episode(
            date: Date(),
            title: "A",
            body: "",
            tags: [Tag(name: "Alpha", nameNormalized: "alpha")]
        )
        let alphaLower = Episode(
            date: Date(),
            title: "B",
            body: "",
            tags: [Tag(name: "alpha", nameNormalized: "alpha")]
        )
        let aardvark = Episode(
            date: Date(),
            title: "C",
            body: "",
            tags: [Tag(name: "Aardvark", nameNormalized: "aardvark")]
        )
        let search = HomeSearchQueryState(freeText: "a", tokens: [], activeField: .tag)
        let items = HomeSearchQueryEngine.suggestions(
            for: search,
            episodes: [alphaUpper, alphaLower, aardvark],
            maxValuesPerField: 2
        )
        let values = items.compactMap { item -> String? in
            if case let .value(field: .tag, value: value) = item.kind {
                return value
            }
            return nil
        }

        XCTAssertEqual(values.count, 2)
        let firstValue = try XCTUnwrap(values.first)
        XCTAssertEqual(firstValue.lowercased(), "alpha")
    }

    func testTagSuggestionsMatchFullwidthHashQuery() {
        _ = makeEpisode(title: "1", body: "", tags: ["#仕事"])
        let search = HomeSearchQueryState(freeText: "＃仕", tokens: [], activeField: .tag)
        let items = HomeSearchQueryEngine.suggestions(for: search, episodes: fetchEpisodes())

        let values = items.compactMap { item -> String? in
            if case let .value(field: .tag, value: value) = item.kind {
                return value
            }
            return nil
        }
        XCTAssertTrue(values.contains("仕事"))
    }

    func testTagSearchNormalizesWhitespaces() {
        let tagged = makeEpisode(title: "Tag target", body: "", tags: ["#TagName"])
        _ = makeEpisode(title: "Other", body: "", tags: ["#Another"])

        let token = HomeSearchFilterToken(field: .tag, value: "#Tag Name")!
        let search = HomeSearchQueryState(freeText: "", tokens: [token], activeField: nil)
        let result = filter(search: search, statusFilter: .all)

        XCTAssertEqual(result.map(\.id), [tagged.id])
    }

    func testHistoryFiltersMatchTalkCountMediaTypeAndReaction() {
        let target = makeEpisode(title: "対象", body: "")
        let other = makeEpisode(title: "他", body: "")

        _ = addUnlockLog(
            to: target,
            talkedAt: Date().addingTimeInterval(-60 * 60 * 24),
            mediaType: ReleaseLogMediaPreset.tv.rawValue,
            reaction: ReleaseLogOutcome.hit.rawValue
        )
        _ = addUnlockLog(
            to: target,
            talkedAt: Date().addingTimeInterval(-60 * 30),
            mediaType: ReleaseLogMediaPreset.streaming.rawValue,
            reaction: ReleaseLogOutcome.soSo.rawValue
        )
        _ = addUnlockLog(
            to: other,
            talkedAt: Date().addingTimeInterval(-60 * 60 * 3),
            mediaType: ReleaseLogMediaPreset.radio.rawValue,
            reaction: ReleaseLogOutcome.shelved.rawValue
        )

        let tokens = [
            HomeSearchFilterToken(field: .talkCount, value: "1回以上")!,
            HomeSearchFilterToken(field: .mediaType, value: "テレビ")!,
            HomeSearchFilterToken(field: .reaction, value: "○")!
        ]
        let search = HomeSearchQueryState(freeText: "", tokens: tokens, activeField: nil)
        let result = filter(search: search, statusFilter: .all)

        XCTAssertEqual(result.map(\.id), [target.id])
    }

    func testLastTalkedDateRangeFilterMatchesExpectedEpisode() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let inRange = makeEpisode(title: "範囲内", body: "")
        let outOfRange = makeEpisode(title: "範囲外", body: "")

        let inRangeDate = calendar.date(byAdding: .day, value: -3, to: now)!
        let outOfRangeDate = calendar.date(byAdding: .day, value: -35, to: now)!
        _ = addUnlockLog(
            to: inRange,
            talkedAt: inRangeDate,
            mediaType: ReleaseLogMediaPreset.sns.rawValue,
            reaction: ReleaseLogOutcome.hit.rawValue
        )
        _ = addUnlockLog(
            to: outOfRange,
            talkedAt: outOfRangeDate,
            mediaType: ReleaseLogMediaPreset.tv.rawValue,
            reaction: ReleaseLogOutcome.soSo.rawValue
        )

        let start = HomeSearchQueryEngineTests.dateString(
            calendar.date(byAdding: .day, value: -7, to: now)!
        )
        let end = HomeSearchQueryEngineTests.dateString(now)
        let token = HomeSearchFilterToken(field: .lastTalkedAt, value: "\(start)~\(end)")!
        let search = HomeSearchQueryState(freeText: "", tokens: [token], activeField: nil)

        let result = filter(search: search, statusFilter: .all)
        XCTAssertEqual(result.map(\.id), [inRange.id])
    }

    func testLastTalkedDateRangeStartOnlyFilterMatchesExpectedEpisode() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let matched = makeEpisode(title: "一致", body: "")
        let unmatched = makeEpisode(title: "不一致", body: "")

        let matchedDate = calendar.date(byAdding: .day, value: -2, to: now)!
        let unmatchedDate = calendar.date(byAdding: .day, value: -20, to: now)!
        _ = addUnlockLog(
            to: matched,
            talkedAt: matchedDate,
            mediaType: ReleaseLogMediaPreset.tv.rawValue,
            reaction: ReleaseLogOutcome.hit.rawValue
        )
        _ = addUnlockLog(
            to: unmatched,
            talkedAt: unmatchedDate,
            mediaType: ReleaseLogMediaPreset.tv.rawValue,
            reaction: ReleaseLogOutcome.hit.rawValue
        )

        let start = HomeSearchQueryEngineTests.dateString(calendar.date(byAdding: .day, value: -7, to: now)!)
        let token = HomeSearchFilterToken(field: .lastTalkedAt, value: "\(start)~")!
        let search = HomeSearchQueryState(freeText: "", tokens: [token], activeField: nil)

        let result = filter(search: search, statusFilter: .all)
        XCTAssertEqual(result.map(\.id), [matched.id])
    }

    func testLastTalkedDateRangeEndOnlyFilterMatchesExpectedEpisode() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let matched = makeEpisode(title: "一致", body: "")
        let unmatched = makeEpisode(title: "不一致", body: "")

        let matchedDate = calendar.date(byAdding: .day, value: -20, to: now)!
        let unmatchedDate = calendar.date(byAdding: .day, value: -1, to: now)!
        _ = addUnlockLog(
            to: matched,
            talkedAt: matchedDate,
            mediaType: ReleaseLogMediaPreset.radio.rawValue,
            reaction: ReleaseLogOutcome.soSo.rawValue
        )
        _ = addUnlockLog(
            to: unmatched,
            talkedAt: unmatchedDate,
            mediaType: ReleaseLogMediaPreset.radio.rawValue,
            reaction: ReleaseLogOutcome.soSo.rawValue
        )

        let end = HomeSearchQueryEngineTests.dateString(calendar.date(byAdding: .day, value: -7, to: now)!)
        let token = HomeSearchFilterToken(field: .lastTalkedAt, value: "~\(end)")!
        let search = HomeSearchQueryState(freeText: "", tokens: [token], activeField: nil)

        let result = filter(search: search, statusFilter: .all)
        XCTAssertEqual(result.map(\.id), [matched.id])
    }

    func testLastTalkedDateFilterMatchesWhenAnyUnlockLogIsInRange() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let episode = makeEpisode(title: "複数ログ", body: "")

        let olderInRange = calendar.date(byAdding: .day, value: -3, to: now)!
        let latestOutOfRange = calendar.date(byAdding: .day, value: -20, to: now)!
        _ = addUnlockLog(
            to: episode,
            talkedAt: olderInRange,
            mediaType: ReleaseLogMediaPreset.sns.rawValue,
            reaction: ReleaseLogOutcome.hit.rawValue
        )
        _ = addUnlockLog(
            to: episode,
            talkedAt: latestOutOfRange,
            mediaType: ReleaseLogMediaPreset.sns.rawValue,
            reaction: ReleaseLogOutcome.soSo.rawValue
        )

        let start = HomeSearchQueryEngineTests.dateString(calendar.date(byAdding: .day, value: -7, to: now)!)
        let end = HomeSearchQueryEngineTests.dateString(now)
        let token = HomeSearchFilterToken(field: .lastTalkedAt, value: "\(start)~\(end)")!
        let search = HomeSearchQueryState(freeText: "", tokens: [token], activeField: nil)

        let result = filter(search: search, statusFilter: .all)
        XCTAssertEqual(result.map(\.id), [episode.id])
    }

    func testRegisteredDateRangeFilterMatchesEpisodeDate() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let inRangeDate = calendar.date(byAdding: .day, value: -5, to: now)!
        let outOfRangeDate = calendar.date(byAdding: .day, value: -40, to: now)!
        let inRange = makeEpisode(title: "範囲内", body: "", date: inRangeDate)
        _ = makeEpisode(title: "範囲外", body: "", date: outOfRangeDate)

        let start = HomeSearchQueryEngineTests.dateString(calendar.date(byAdding: .day, value: -7, to: now)!)
        let end = HomeSearchQueryEngineTests.dateString(now)
        let token = HomeSearchFilterToken(field: .registeredDate, value: "\(start)~\(end)")!
        let search = HomeSearchQueryState(freeText: "", tokens: [token], activeField: nil)

        let result = filter(search: search, statusFilter: .all)
        XCTAssertEqual(result.map(\.id), [inRange.id])
    }

    func testRegisteredDateRangeSingleSidedFilterMatchesEpisodeDate() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let matchedDate = calendar.date(byAdding: .day, value: -2, to: now)!
        let unmatchedDate = calendar.date(byAdding: .day, value: -15, to: now)!
        let matched = makeEpisode(title: "一致", body: "", date: matchedDate)
        _ = makeEpisode(title: "不一致", body: "", date: unmatchedDate)

        let start = HomeSearchQueryEngineTests.dateString(calendar.date(byAdding: .day, value: -7, to: now)!)
        let token = HomeSearchFilterToken(field: .registeredDate, value: "\(start)~")!
        let search = HomeSearchQueryState(freeText: "", tokens: [token], activeField: nil)

        let result = filter(search: search, statusFilter: .all)
        XCTAssertEqual(result.map(\.id), [matched.id])
    }
}

@MainActor
private extension HomeSearchQueryEngineTests {
    func makeEpisode(
        title: String,
        body: String,
        date: Date = Date(),
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
            date: date,
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

    @discardableResult
    func addUnlockLog(
        to episode: Episode,
        talkedAt: Date,
        mediaType: String?,
        reaction: String
    ) -> UnlockLog {
        context.createUnlockLog(
            episode: episode,
            talkedAt: talkedAt,
            mediaPublicAt: nil,
            mediaType: mediaType,
            projectNameText: "番組",
            reaction: reaction,
            memo: ""
        )
    }

    static func dateString(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: value)
    }
}
