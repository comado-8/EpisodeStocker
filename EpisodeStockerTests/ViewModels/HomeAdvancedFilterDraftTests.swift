import XCTest
@testable import EpisodeStocker

final class HomeAdvancedFilterDraftTests: XCTestCase {
    func testToHistoryTokensContainsTalkCountPreset() throws {
        let draft = HomeAdvancedFilterDraft(talkCountPreset: .atLeastOne)

        let tokens = draft.toHistoryTokens()
        let talkCountToken = try XCTUnwrap(tokens.first(where: { $0.field == .talkCount }))
        XCTAssertEqual(talkCountToken.value, "1回以上")
    }

    func testToHistoryTokensContainsLastTalkedDateRange() throws {
        let start = makeDate(2026, 2, 1)
        let end = makeDate(2026, 2, 15)
        let draft = HomeAdvancedFilterDraft(startDate: start, endDate: end)

        let tokens = draft.toHistoryTokens()
        let dateToken = try XCTUnwrap(tokens.first(where: { $0.field == .lastTalkedAt }))
        XCTAssertEqual(dateToken.value, "2026/02/01~2026/02/15")
    }

    func testToHistoryTokensCreatesDateTokenWhenOnlyOneSideIsSet() throws {
        let startOnly = HomeAdvancedFilterDraft(startDate: makeDate(2026, 2, 1), endDate: nil)
        let endOnly = HomeAdvancedFilterDraft(startDate: nil, endDate: makeDate(2026, 2, 15))

        let startOnlyToken = try XCTUnwrap(startOnly.toHistoryTokens().first(where: { $0.field == .lastTalkedAt }))
        let endOnlyToken = try XCTUnwrap(endOnly.toHistoryTokens().first(where: { $0.field == .lastTalkedAt }))
        XCTAssertEqual(startOnlyToken.value, "2026/02/01~")
        XCTAssertEqual(endOnlyToken.value, "~2026/02/15")
    }

    func testToHistoryTokensNormalizesDateOrderWhenStartIsAfterEnd() throws {
        let draft = HomeAdvancedFilterDraft(
            startDate: makeDate(2026, 2, 20),
            endDate: makeDate(2026, 2, 10)
        )

        let tokens = draft.toHistoryTokens()
        let dateToken = try XCTUnwrap(tokens.first(where: { $0.field == .lastTalkedAt }))
        XCTAssertEqual(dateToken.value, "2026/02/10~2026/02/20")
    }

    func testToHistoryTokensContainsRegisteredDateRange() throws {
        let draft = HomeAdvancedFilterDraft(
            episodeDateStart: makeDate(2026, 2, 2),
            episodeDateEnd: makeDate(2026, 2, 10)
        )
        let tokens = draft.toHistoryTokens()
        let token = try XCTUnwrap(tokens.first(where: { $0.field == .registeredDate }))
        XCTAssertEqual(token.value, "2026/02/02~2026/02/10")
    }

    func testToHistoryTokensContainsRegisteredDateSingleSidedToken() throws {
        let startOnlyDraft = HomeAdvancedFilterDraft(
            episodeDateStart: makeDate(2026, 2, 3),
            episodeDateEnd: nil
        )
        let endOnlyDraft = HomeAdvancedFilterDraft(
            episodeDateStart: nil,
            episodeDateEnd: makeDate(2026, 2, 18)
        )

        let startToken = try XCTUnwrap(
            startOnlyDraft.toHistoryTokens().first(where: { $0.field == .registeredDate }))
        let endToken = try XCTUnwrap(
            endOnlyDraft.toHistoryTokens().first(where: { $0.field == .registeredDate }))
        XCTAssertEqual(startToken.value, "2026/02/03~")
        XCTAssertEqual(endToken.value, "~2026/02/18")
    }

    func testToHistoryTokensContainsMediaAndReactionTokens() {
        let draft = HomeAdvancedFilterDraft(
            mediaTypes: [ReleaseLogMediaPreset.streaming.rawValue, ReleaseLogMediaPreset.tv.rawValue],
            reactions: [.hit, .shelved]
        )

        let tokens = draft.toHistoryTokens()
        let mediaValues = Set(tokens.filter { $0.field == .mediaType }.map(\.value))
        let reactionValues = Set(tokens.filter { $0.field == .reaction }.map(\.value))

        XCTAssertEqual(
            mediaValues,
            Set([ReleaseLogMediaPreset.streaming.rawValue, ReleaseLogMediaPreset.tv.rawValue])
        )
        XCTAssertEqual(
            reactionValues,
            Set([ReleaseLogOutcome.hit.rawValue, ReleaseLogOutcome.shelved.rawValue])
        )
    }

    func testRemovingHistoryTokensKeepsNonHistoryTokens() throws {
        let tokens: [HomeSearchFilterToken] = [
            try makeToken(field: .tag, value: "仕事"),
            try makeToken(field: .person, value: "田中"),
            try makeToken(field: .talkCount, value: "1回以上"),
            try makeToken(field: .registeredDate, value: "2026/02/01~2026/02/28"),
            try makeToken(field: .mediaType, value: ReleaseLogMediaPreset.tv.rawValue),
            try makeToken(field: .reaction, value: ReleaseLogOutcome.hit.rawValue)
        ]

        let filtered = HomeAdvancedFilterDraft.removingHistoryTokens(from: tokens)
        let fields = filtered.map(\.field)

        XCTAssertEqual(fields, [.tag, .person])
    }

    func testInitFromTokensRestoresHistoryDraftValues() throws {
        let tokens: [HomeSearchFilterToken] = [
            try makeToken(field: .talkCount, value: "3回以上"),
            try makeToken(field: .lastTalkedAt, value: "2026/02/01~"),
            try makeToken(field: .registeredDate, value: "~2026/02/28"),
            try makeToken(field: .mediaType, value: ReleaseLogMediaPreset.radio.rawValue),
            try makeToken(field: .reaction, value: ReleaseLogOutcome.soSo.rawValue)
        ]

        let draft = HomeAdvancedFilterDraft(tokens: tokens)

        XCTAssertEqual(draft.talkCountPreset, .atLeastThree)
        XCTAssertEqual(draft.startDate, makeDate(2026, 2, 1))
        XCTAssertNil(draft.endDate)
        XCTAssertNil(draft.episodeDateStart)
        XCTAssertEqual(draft.episodeDateEnd, makeDate(2026, 2, 28))
        XCTAssertEqual(draft.mediaTypes, Set([ReleaseLogMediaPreset.radio.rawValue]))
        XCTAssertEqual(draft.reactions, Set([.soSo]))
    }
}

private extension HomeAdvancedFilterDraftTests {
    func makeToken(field: HomeSearchField, value: String) throws -> HomeSearchFilterToken {
        try XCTUnwrap(HomeSearchFilterToken(field: field, value: value))
    }

    func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)!
    }
}
