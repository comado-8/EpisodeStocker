import XCTest
@testable import EpisodeStocker

final class EpisodeModelTests: XCTestCase {
    func testIsUnlockedReturnsFalseWhenUnlockDateIsNil() {
        let episode = Episode(date: Date(), title: "No unlock date")
        episode.unlockDate = nil

        XCTAssertFalse(episode.isUnlocked)
    }

    func testIsUnlockedReturnsTrueWhenUnlockDateIsInPast() {
        let episode = Episode(date: Date(), title: "Past unlock", unlockDate: Date().addingTimeInterval(-60))

        XCTAssertTrue(episode.isUnlocked)
    }

    func testIsUnlockedReturnsFalseWhenUnlockDateIsInFuture() {
        let episode = Episode(date: Date(), title: "Future unlock", unlockDate: Date().addingTimeInterval(60))

        XCTAssertFalse(episode.isUnlocked)
    }

    func testActiveUnlockLogsAndTalkedCountExcludeSoftDeletedLogs() {
        let episode = Episode(date: makeDate(2026, 2, 1), title: "Logs")
        let activeLog = UnlockLog(
            talkedAt: makeDate(2026, 2, 3),
            mediaType: ReleaseLogMediaPreset.tv.rawValue,
            reaction: ReleaseLogOutcome.hit.rawValue,
            memo: "active",
            episode: episode,
            isSoftDeleted: false
        )
        let deletedLog = UnlockLog(
            talkedAt: makeDate(2026, 2, 4),
            mediaType: ReleaseLogMediaPreset.radio.rawValue,
            reaction: ReleaseLogOutcome.soSo.rawValue,
            memo: "deleted",
            episode: episode,
            isSoftDeleted: true
        )
        episode.unlockLogs = [activeLog, deletedLog]

        XCTAssertEqual(episode.activeUnlockLogs.count, 1)
        XCTAssertEqual(episode.activeUnlockLogs.first?.id, activeLog.id)
        XCTAssertEqual(episode.talkedCount, 1)
    }

    func testLatestTalkedAtUsesLatestActiveUnlockLog() {
        let episode = Episode(date: makeDate(2026, 2, 1), title: "Latest")
        let oldest = UnlockLog(
            talkedAt: makeDate(2026, 2, 2),
            reaction: ReleaseLogOutcome.hit.rawValue,
            memo: "old",
            episode: episode
        )
        let latestActive = UnlockLog(
            talkedAt: makeDate(2026, 2, 10),
            reaction: ReleaseLogOutcome.soSo.rawValue,
            memo: "latest active",
            episode: episode
        )
        let latestDeleted = UnlockLog(
            talkedAt: makeDate(2026, 2, 12),
            reaction: ReleaseLogOutcome.shelved.rawValue,
            memo: "latest deleted",
            episode: episode,
            isSoftDeleted: true
        )
        episode.unlockLogs = [oldest, latestDeleted, latestActive]

        XCTAssertEqual(episode.latestTalkedAt, latestActive.talkedAt)
    }

    func testReactionCountCountsOnlyMatchingActiveLogs() {
        let episode = Episode(date: makeDate(2026, 2, 1), title: "Reactions")
        episode.unlockLogs = [
            UnlockLog(
                talkedAt: makeDate(2026, 2, 3),
                reaction: ReleaseLogOutcome.hit.rawValue,
                memo: "",
                episode: episode
            ),
            UnlockLog(
                talkedAt: makeDate(2026, 2, 4),
                reaction: ReleaseLogOutcome.hit.rawValue,
                memo: "",
                episode: episode,
                isSoftDeleted: true
            ),
            UnlockLog(
                talkedAt: makeDate(2026, 2, 5),
                reaction: ReleaseLogOutcome.soSo.rawValue,
                memo: "",
                episode: episode
            ),
            UnlockLog(
                talkedAt: makeDate(2026, 2, 6),
                reaction: ReleaseLogOutcome.shelved.rawValue,
                memo: "",
                episode: episode
            )
        ]

        XCTAssertEqual(episode.reactionCount(.hit), 1)
        XCTAssertEqual(episode.reactionCount(.soSo), 1)
        XCTAssertEqual(episode.reactionCount(.shelved), 1)
    }

    func testHistoryComputedPropertiesForEmptyUnlockLogs() {
        let episode = Episode(date: makeDate(2026, 2, 1), title: "Empty")
        episode.unlockLogs = []

        XCTAssertTrue(episode.activeUnlockLogs.isEmpty)
        XCTAssertEqual(episode.talkedCount, 0)
        XCTAssertNil(episode.latestTalkedAt)
        XCTAssertEqual(episode.reactionCount(.hit), 0)
    }

    func testEpisodeInitializerAssignsProvidedValues() {
        let now = makeDate(2026, 2, 20)
        let created = makeDate(2026, 2, 21)
        let deleted = makeDate(2026, 2, 22)
        let tag = Tag(name: "#仕事", nameNormalized: "仕事")
        let person = Person(name: "田中", nameNormalized: "田中")
        let project = Project(name: "朝番組", nameNormalized: "朝番組")
        let emotion = Emotion(name: "ワクワク", nameNormalized: "ワクワク")
        let place = Place(name: "渋谷", nameNormalized: "渋谷")
        let episode = Episode(
            id: UUID(),
            date: now,
            title: "Init",
            body: "Body",
            unlockDate: now,
            type: "memo",
            createdAt: created,
            updatedAt: created,
            isSoftDeleted: true,
            deletedAt: deleted,
            tags: [tag],
            persons: [person],
            projects: [project],
            emotions: [emotion],
            places: [place],
            unlockLogs: []
        )

        XCTAssertEqual(episode.date, now)
        XCTAssertEqual(episode.title, "Init")
        XCTAssertEqual(episode.body, "Body")
        XCTAssertEqual(episode.unlockDate, now)
        XCTAssertEqual(episode.type, "memo")
        XCTAssertEqual(episode.createdAt, created)
        XCTAssertEqual(episode.updatedAt, created)
        XCTAssertTrue(episode.isSoftDeleted)
        XCTAssertEqual(episode.deletedAt, deleted)
        XCTAssertEqual(episode.tags.count, 1)
        XCTAssertEqual(episode.persons.count, 1)
        XCTAssertEqual(episode.projects.count, 1)
        XCTAssertEqual(episode.emotions.count, 1)
        XCTAssertEqual(episode.places.count, 1)
    }

    func testReleaseLogAndSettingIdentityProperties() {
        XCTAssertEqual(ReleaseLogOutcome.hit.id, ReleaseLogOutcome.hit.rawValue)
        XCTAssertEqual(ReleaseLogOutcome.soSo.label, ReleaseLogOutcome.soSo.rawValue)
        XCTAssertEqual(ReleaseLogMediaPreset.sns.id, ReleaseLogMediaPreset.sns.rawValue)

        let item = SettingItem(key: "k", value: "v")
        XCTAssertFalse(item.id.uuidString.isEmpty)
    }
}

private extension EpisodeModelTests {
    func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = .current
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)!
    }
}
