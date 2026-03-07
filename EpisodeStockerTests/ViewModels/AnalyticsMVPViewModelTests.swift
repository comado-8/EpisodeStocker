import XCTest
@testable import EpisodeStocker

@MainActor
final class AnalyticsMVPViewModelTests: XCTestCase {
    func testRefreshBuildsSnapshotAndClearsLoadingState() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let vm = AnalyticsMVPViewModel(
            nowProvider: { now },
            timeZone: TimeZone(identifier: "Asia/Tokyo") ?? .current
        )
        let episode = makeEpisode(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            title: "alpha",
            date: now.addingTimeInterval(-86_400),
            tags: [" #TagOne ", "TagTwo"],
            logs: [
                (now.addingTimeInterval(-3_600), ReleaseLogOutcome.hit.rawValue, false),
                (now.addingTimeInterval(-1_800), ReleaseLogOutcome.soSo.rawValue, true)
            ]
        )

        await vm.refresh(episodes: [episode])

        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.snapshot?.monthlyTalkCount, 1)
        XCTAssertEqual(vm.snapshot?.topTalkedEpisodes.first?.title, "alpha")
    }

    func testRefreshUsesCacheForUnchangedFingerprint() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let vm = AnalyticsMVPViewModel(
            nowProvider: { now },
            timeZone: TimeZone(identifier: "Asia/Tokyo") ?? .current
        )
        let episode = makeEpisode(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            title: "cached",
            date: now,
            tags: ["tag"],
            logs: [(now.addingTimeInterval(-300), ReleaseLogOutcome.hit.rawValue, false)]
        )

        await vm.refresh(episodes: [episode])
        let firstSnapshot = vm.snapshot
        await vm.refresh(episodes: [episode])

        XCTAssertEqual(vm.snapshot, firstSnapshot)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func testRefreshRecomputesWhenHourBucketChanges() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let janNow = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 1,
            day: 31,
            hour: 23,
            minute: 30
        ))!
        let janLog = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 1,
            day: 31,
            hour: 12,
            minute: 0
        ))!
        var currentNow = janNow
        let vm = AnalyticsMVPViewModel(
            nowProvider: { currentNow },
            timeZone: TimeZone(identifier: "Asia/Tokyo") ?? .current
        )
        let episode = makeEpisode(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            title: "boundary",
            date: janLog,
            tags: [],
            logs: [(janLog, ReleaseLogOutcome.hit.rawValue, false)]
        )

        await vm.refresh(episodes: [episode])
        let firstMonthlyTalkCount = vm.snapshot?.monthlyTalkCount

        currentNow = currentNow.addingTimeInterval(7_200)
        await vm.refresh(episodes: [episode])
        let secondMonthlyTalkCount = vm.snapshot?.monthlyTalkCount

        XCTAssertNotEqual(firstMonthlyTalkCount, secondMonthlyTalkCount)
    }

    func testConcurrentRefreshKeepsLatestResult() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let vm = AnalyticsMVPViewModel(
            nowProvider: { now },
            timeZone: TimeZone(identifier: "Asia/Tokyo") ?? .current
        )
        let heavyEpisodes = (0..<250).map { index in
            makeEpisode(
                id: UUID(),
                title: "ep-\(index)",
                date: now.addingTimeInterval(Double(-index * 60)),
                tags: ["t\(index % 5)"],
                logs: (0..<20).map { logIndex in
                    (
                        now.addingTimeInterval(Double(-(index * 20 + logIndex) * 60)),
                        logIndex.isMultiple(of: 2) ? ReleaseLogOutcome.hit.rawValue : ReleaseLogOutcome.soSo.rawValue,
                        false
                    )
                }
            )
        }

        async let first: Void = vm.refresh(episodes: heavyEpisodes)
        await Task.yield()
        async let second: Void = vm.refresh(episodes: [])
        _ = await (first, second)

        XCTAssertEqual(vm.snapshot?.monthlyTalkCount, 0)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    private func makeEpisode(
        id: UUID,
        title: String,
        date: Date,
        tags: [String],
        logs: [(date: Date, reaction: String, isSoftDeleted: Bool)]
    ) -> Episode {
        let normalizedTags = tags.map {
            Tag(name: $0, nameNormalized: $0.lowercased())
        }
        let episode = Episode(
            id: id,
            date: date,
            title: title,
            createdAt: date,
            updatedAt: date,
            tags: normalizedTags
        )
        episode.unlockLogs = logs.map { log in
            UnlockLog(
                talkedAt: log.date,
                reaction: log.reaction,
                memo: "",
                episode: episode,
                createdAt: log.date,
                updatedAt: log.date,
                isSoftDeleted: log.isSoftDeleted
            )
        }
        return episode
    }
}
