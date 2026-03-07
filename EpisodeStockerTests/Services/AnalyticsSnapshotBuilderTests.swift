import XCTest
@testable import EpisodeStocker

final class AnalyticsSnapshotBuilderTests: XCTestCase {
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    func testStrongRankingExcludesEpisodesWithLessThanThreeTalks() throws {
        let now = try makeDate(2026, 3, 5, 12, 0)
        let episodes = [
            makeEpisode(
                title: "2回だけ",
                tags: [],
                logs: [
                    try makeLog(daysAgo: 1, reaction: ReleaseLogOutcome.hit.rawValue, now: now),
                    try makeLog(daysAgo: 3, reaction: ReleaseLogOutcome.hit.rawValue, now: now),
                ]
            ),
            makeEpisode(
                title: "3回以上",
                tags: [],
                logs: [
                    try makeLog(daysAgo: 1, reaction: ReleaseLogOutcome.hit.rawValue, now: now),
                    try makeLog(daysAgo: 2, reaction: ReleaseLogOutcome.hit.rawValue, now: now),
                    try makeLog(daysAgo: 4, reaction: ReleaseLogOutcome.soSo.rawValue, now: now),
                ]
            ),
        ]

        let snapshot = AnalyticsSnapshotBuilder.build(episodes: episodes, now: now, timeZone: tokyo)

        XCTAssertEqual(snapshot.strongEpisodes.count, 1)
        XCTAssertEqual(snapshot.strongEpisodes.first?.title, "3回以上")
    }

    func testOverusedCountsOnlyLogsWithinLast30DaysIncludingBoundary() throws {
        let now = try makeDate(2026, 3, 5, 12, 0)
        let episode = makeEpisode(
            title: "境界テスト",
            tags: [],
            logs: [
                try makeLog(daysAgo: 30, reaction: ReleaseLogOutcome.soSo.rawValue, now: now),
                try makeLog(daysAgo: 31, reaction: ReleaseLogOutcome.soSo.rawValue, now: now),
            ]
        )

        let snapshot = AnalyticsSnapshotBuilder.build(episodes: [episode], now: now, timeZone: tokyo)

        XCTAssertEqual(snapshot.overusedEpisodes.count, 1)
        XCTAssertEqual(snapshot.overusedEpisodes.first?.recent30DayTalkCount, 1)
    }

    func testDormantOrdersNeverTalkedFirstThenOldestLastTalkedAt() throws {
        let now = try makeDate(2026, 3, 5, 12, 0)
        let never = makeEpisode(title: "未トーク", tags: [], logs: [])
        let old = makeEpisode(
            title: "古い",
            tags: [],
            logs: [try makeLog(daysAgo: 10, reaction: ReleaseLogOutcome.soSo.rawValue, now: now)]
        )
        let recent = makeEpisode(
            title: "新しい",
            tags: [],
            logs: [try makeLog(daysAgo: 2, reaction: ReleaseLogOutcome.soSo.rawValue, now: now)]
        )

        let snapshot = AnalyticsSnapshotBuilder.build(episodes: [recent, old, never], now: now, timeZone: tokyo)

        XCTAssertEqual(snapshot.dormantEpisodes.count, 3)
        XCTAssertEqual(snapshot.dormantEpisodes[0].title, "未トーク")
        XCTAssertEqual(snapshot.dormantEpisodes[1].title, "古い")
        XCTAssertEqual(snapshot.dormantEpisodes[2].title, "新しい")
    }

    func testDigUpSuggestionsOrderByHitRateTimesUnusedDays() throws {
        let now = try makeDate(2026, 3, 5, 12, 0)
        let higherScore = makeEpisode(
            title: "高スコア",
            tags: [],
            logs: [
                try makeLog(daysAgo: 30, reaction: ReleaseLogOutcome.hit.rawValue, now: now),
                try makeLog(daysAgo: 31, reaction: ReleaseLogOutcome.hit.rawValue, now: now),
                try makeLog(daysAgo: 32, reaction: ReleaseLogOutcome.soSo.rawValue, now: now),
            ]
        )
        let lowerScore = makeEpisode(
            title: "低スコア",
            tags: [],
            logs: [
                try makeLog(daysAgo: 10, reaction: ReleaseLogOutcome.hit.rawValue, now: now),
                try makeLog(daysAgo: 11, reaction: ReleaseLogOutcome.hit.rawValue, now: now),
                try makeLog(daysAgo: 12, reaction: ReleaseLogOutcome.hit.rawValue, now: now),
            ]
        )

        let snapshot = AnalyticsSnapshotBuilder.build(episodes: [lowerScore, higherScore], now: now, timeZone: tokyo)

        XCTAssertEqual(snapshot.digUpSuggestions.count, 2)
        XCTAssertEqual(snapshot.digUpSuggestions.first?.title, "高スコア")
    }

    func testTagHitRateFiltersTagsWithAtLeastThreeTalks() throws {
        let now = try makeDate(2026, 3, 5, 12, 0)
        let alpha = makeEpisode(
            title: "alpha",
            tags: ["alpha"],
            logs: [
                try makeLog(daysAgo: 1, reaction: ReleaseLogOutcome.hit.rawValue, now: now),
                try makeLog(daysAgo: 2, reaction: ReleaseLogOutcome.hit.rawValue, now: now),
            ]
        )
        let betaPrimary = makeEpisode(
            title: "beta-1",
            tags: ["beta"],
            logs: [
                try makeLog(daysAgo: 1, reaction: ReleaseLogOutcome.hit.rawValue, now: now),
                try makeLog(daysAgo: 3, reaction: ReleaseLogOutcome.soSo.rawValue, now: now),
            ]
        )
        let betaSecondary = makeEpisode(
            title: "beta-2",
            tags: ["beta"],
            logs: [
                try makeLog(daysAgo: 4, reaction: ReleaseLogOutcome.hit.rawValue, now: now),
                try makeLog(daysAgo: 5, reaction: ReleaseLogOutcome.hit.rawValue, now: now),
            ]
        )

        let snapshot = AnalyticsSnapshotBuilder.build(
            episodes: [alpha, betaPrimary, betaSecondary],
            now: now,
            timeZone: tokyo
        )

        XCTAssertEqual(snapshot.tagHitRates.count, 1)
        XCTAssertEqual(snapshot.tagHitRates.first?.tagName, "beta")
        XCTAssertEqual(snapshot.tagHitRates.first?.talkCount, 4)
        let betaHitRate = try XCTUnwrap(snapshot.tagHitRates.first?.hitRate)
        XCTAssertEqual(betaHitRate, 0.75, accuracy: 0.0001)
    }

    func testNoDivisionByZeroWhenEpisodeHasNoTalkLogs() throws {
        let now = try makeDate(2026, 3, 5, 12, 0)
        let episode = makeEpisode(title: "ゼロ", tags: ["x"], logs: [])

        let snapshot = AnalyticsSnapshotBuilder.build(episodes: [episode], now: now, timeZone: tokyo)

        XCTAssertTrue(snapshot.strongEpisodes.isEmpty)
        XCTAssertTrue(snapshot.digUpSuggestions.isEmpty)
    }

    private func makeEpisode(
        title: String,
        tags: [String],
        logs: [AnalyticsTalkLogInput]
    ) -> AnalyticsEpisodeInput {
        AnalyticsEpisodeInput(
            episodeID: UUID(),
            title: title,
            tags: tags,
            logs: logs
        )
    }

    private func makeLog(daysAgo: Int, reaction: String, now: Date) throws -> AnalyticsTalkLogInput {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        let date = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -daysAgo, to: now),
            "Failed to construct talkedAt for daysAgo=\(daysAgo)"
        )
        return AnalyticsTalkLogInput(talkedAt: date, reaction: reaction)
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) throws -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = tokyo
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return try XCTUnwrap(
            components.date,
            "Failed to construct date for \(year)-\(month)-\(day) \(hour):\(minute)"
        )
    }
}
