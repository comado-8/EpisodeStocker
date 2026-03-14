import XCTest
@testable import EpisodeStocker

final class EpisodeModelTests: XCTestCase {
    func testEpisodeDefaultInitializerAndRelationshipAccessors() {
        let episode = Episode()

        XCTAssertFalse(episode.id.uuidString.isEmpty)
        XCTAssertTrue(episode.title.isEmpty)
        XCTAssertNil(episode.body)
        XCTAssertNil(episode.unlockDate)
        XCTAssertNil(episode.type)
        XCTAssertFalse(episode.isSoftDeleted)
        XCTAssertNil(episode.deletedAt)
        XCTAssertTrue(episode.tags.isEmpty)
        XCTAssertTrue(episode.persons.isEmpty)
        XCTAssertTrue(episode.projects.isEmpty)
        XCTAssertTrue(episode.emotions.isEmpty)
        XCTAssertTrue(episode.places.isEmpty)
        XCTAssertTrue(episode.unlockLogs.isEmpty)

        let tag = Tag(name: "#仕事", nameNormalized: "仕事")
        let person = Person(name: "田中", nameNormalized: "田中")
        let project = Project(name: "朝番組", nameNormalized: "朝番組")
        let emotion = Emotion(name: "わくわく", nameNormalized: "わくわく")
        let place = Place(name: "渋谷", nameNormalized: "渋谷")
        let log = UnlockLog(
            talkedAt: Date(),
            reaction: ReleaseLogOutcome.hit.rawValue,
            memo: "memo",
            episode: episode
        )

        episode.tags = [tag]
        episode.persons = [person]
        episode.projects = [project]
        episode.emotions = [emotion]
        episode.places = [place]
        episode.unlockLogs = [log]

        XCTAssertEqual(episode.tags.first?.id, tag.id)
        XCTAssertEqual(episode.persons.first?.id, person.id)
        XCTAssertEqual(episode.projects.first?.id, project.id)
        XCTAssertEqual(episode.emotions.first?.id, emotion.id)
        XCTAssertEqual(episode.places.first?.id, place.id)
        XCTAssertEqual(episode.unlockLogs.first?.id, log.id)
    }

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

    func testUnlockLogInitializerAndEpisodeAccessors() {
        let episode1 = Episode(date: makeDate(2026, 2, 1), title: "E1")
        let episode2 = Episode(date: makeDate(2026, 2, 2), title: "E2")
        let talkedAt = makeDate(2026, 2, 3)
        let createdAt = makeDate(2026, 2, 4)
        let updatedAt = makeDate(2026, 2, 5)
        let deletedAt = makeDate(2026, 2, 6)

        let log = UnlockLog(
            id: UUID(),
            talkedAt: talkedAt,
            mediaPublicAt: makeDate(2026, 2, 10),
            mediaType: ReleaseLogMediaPreset.streaming.rawValue,
            projectNameText: "P",
            reaction: ReleaseLogOutcome.soSo.rawValue,
            memo: "Memo",
            episode: episode1,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isSoftDeleted: true,
            deletedAt: deletedAt
        )

        XCTAssertEqual(log.talkedAt, talkedAt)
        XCTAssertEqual(log.mediaType, ReleaseLogMediaPreset.streaming.rawValue)
        XCTAssertEqual(log.projectNameText, "P")
        XCTAssertEqual(log.reaction, ReleaseLogOutcome.soSo.rawValue)
        XCTAssertEqual(log.memo, "Memo")
        XCTAssertEqual(log.createdAt, createdAt)
        XCTAssertEqual(log.updatedAt, updatedAt)
        XCTAssertTrue(log.isSoftDeleted)
        XCTAssertEqual(log.deletedAt, deletedAt)
        XCTAssertEqual(log.episode?.id, episode1.id)
        XCTAssertEqual(log.episode?.id, episode1.id)

        log.episode = episode2
        XCTAssertEqual(log.episode?.id, episode2.id)
        XCTAssertEqual(log.episode?.id, episode2.id)

        log.episode = nil
        XCTAssertNil(log.episode)
        XCTAssertNil(log.episode)
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

    func testEntityInitializersAndEpisodesAccessors() {
        let episode = Episode(date: makeDate(2026, 2, 1), title: "Target")
        let date = makeDate(2026, 2, 2)

        let tag = Tag(
            id: UUID(),
            name: "#学び",
            nameNormalized: "学び",
            createdAt: date,
            updatedAt: date,
            isSoftDeleted: true,
            deletedAt: date,
            episodes: [episode]
        )
        XCTAssertEqual(tag.episodes.count, 1)
        XCTAssertEqual(tag.episodes.first?.id, episode.id)
        XCTAssertTrue(tag.isSoftDeleted)
        XCTAssertEqual(tag.deletedAt, date)

        let person = Person(
            id: UUID(),
            name: "Alice",
            nameNormalized: "alice",
            createdAt: date,
            updatedAt: date,
            isSoftDeleted: true,
            deletedAt: date,
            episodes: [episode]
        )
        XCTAssertEqual(person.episodes.count, 1)
        XCTAssertEqual(person.episodes.first?.id, episode.id)

        let project = Project(
            id: UUID(),
            name: "Morning Show",
            nameNormalized: "morning show",
            createdAt: date,
            updatedAt: date,
            isSoftDeleted: true,
            deletedAt: date,
            episodes: [episode]
        )
        XCTAssertEqual(project.episodes.count, 1)
        XCTAssertEqual(project.episodes.first?.id, episode.id)

        let emotion = Emotion(
            id: UUID(),
            name: "嬉しい",
            nameNormalized: "嬉しい",
            createdAt: date,
            updatedAt: date,
            isSoftDeleted: true,
            deletedAt: date,
            episodes: [episode]
        )
        XCTAssertEqual(emotion.episodes.count, 1)
        XCTAssertEqual(emotion.episodes.first?.id, episode.id)

        let place = Place(
            id: UUID(),
            name: "渋谷",
            nameNormalized: "渋谷",
            createdAt: date,
            updatedAt: date,
            isSoftDeleted: true,
            deletedAt: date,
            episodes: [episode]
        )
        XCTAssertEqual(place.episodes.count, 1)
        XCTAssertEqual(place.episodes.first?.id, episode.id)

        let another = Episode(date: makeDate(2026, 2, 9), title: "Another")
        tag.episodes = [another]
        person.episodes = [another]
        project.episodes = [another]
        emotion.episodes = [another]
        place.episodes = [another]

        XCTAssertEqual(tag.episodes.first?.id, another.id)
        XCTAssertEqual(person.episodes.first?.id, another.id)
        XCTAssertEqual(project.episodes.first?.id, another.id)
        XCTAssertEqual(emotion.episodes.first?.id, another.id)
        XCTAssertEqual(place.episodes.first?.id, another.id)
    }

    func testReleaseLogAndSettingIdentityProperties() {
        XCTAssertEqual(ReleaseLogOutcome.hit.id, ReleaseLogOutcome.hit.rawValue)
        XCTAssertEqual(ReleaseLogOutcome.soSo.label, ReleaseLogOutcome.soSo.rawValue)
        XCTAssertEqual(ReleaseLogMediaPreset.sns.id, ReleaseLogMediaPreset.sns.rawValue)

        let item = SettingItem(key: "k", value: "v")
        XCTAssertFalse(item.id.uuidString.isEmpty)
    }

    func testAllReleaseMediaPresetsAndSubscriptionPlansAreCovered() {
        let presetValues = ReleaseLogMediaPreset.allCases.map(\.rawValue)
        XCTAssertEqual(
            presetValues,
            ["テレビ", "配信", "ラジオ", "雑誌", "イベント", "SNS", "その他"]
        )
        XCTAssertEqual(ReleaseLogMediaPreset.allCases.map(\.id), presetValues)

        XCTAssertEqual(
            SubscriptionStatus.Plan.allCases.map(\.rawValue),
            ["free", "monthly", "yearly"]
        )

        let monthly = SubscriptionStatus(
            plan: .monthly,
            expiryDate: makeDate(2026, 3, 1),
            trialEndDate: nil,
            willAutoRenew: false
        )
        let yearly = SubscriptionStatus(
            plan: .yearly,
            expiryDate: makeDate(2027, 3, 1),
            trialEndDate: nil,
            willAutoRenew: false
        )
        XCTAssertEqual(monthly.plan, .monthly)
        XCTAssertNil(monthly.nextPlan)
        XCTAssertNil(monthly.nextPlanEffectiveDate)
        XCTAssertEqual(monthly.willAutoRenew, false)
        XCTAssertEqual(yearly.plan, .yearly)
        XCTAssertNil(yearly.nextPlan)
        XCTAssertNil(yearly.nextPlanEffectiveDate)
        XCTAssertEqual(yearly.willAutoRenew, false)
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
