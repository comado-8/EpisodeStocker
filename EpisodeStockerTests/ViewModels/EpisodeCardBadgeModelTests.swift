import XCTest
@testable import EpisodeStocker

final class EpisodeCardBadgeModelTests: XCTestCase {
    func testNoTalkHistoryHidesReactionBadge() {
        let model = EpisodeCardBadgeModel.make(
            talkedCount: 0,
            latestTalkedAt: nil,
            reactionCounts: EpisodeCardReactionCounts(hit: 2, soSo: 1, shelved: 3)
        )

        XCTAssertEqual(model.talkedCountText, "0回")
        XCTAssertEqual(model.latestTalkedAtText, "-")
        XCTAssertFalse(model.showsReactionBadge)
    }

    func testTalkHistoryShowsReactionBadge() {
        let model = EpisodeCardBadgeModel.make(
            talkedCount: 2,
            latestTalkedAt: nil,
            reactionCounts: EpisodeCardReactionCounts(hit: 0, soSo: 0, shelved: 0)
        )

        XCTAssertTrue(model.showsReactionBadge)
    }

    func testLatestTalkedAtUsesDateFormat() throws {
        let date = try XCTUnwrap(
            Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 2, day: 25))
        )

        let model = EpisodeCardBadgeModel.make(
            talkedCount: 1,
            latestTalkedAt: date,
            reactionCounts: EpisodeCardReactionCounts(hit: 1, soSo: 0, shelved: 0)
        )

        XCTAssertEqual(model.latestTalkedAtText, "2026/02/25")
    }

    func testReactionCountsAreKeptAsIs() {
        let counts = EpisodeCardReactionCounts(hit: 4, soSo: 5, shelved: 6)

        let model = EpisodeCardBadgeModel.make(
            talkedCount: 3,
            latestTalkedAt: nil,
            reactionCounts: counts
        )

        XCTAssertEqual(model.reactionCounts, counts)
    }
}
