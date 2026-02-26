import XCTest
@testable import EpisodeStocker

final class EpisodeCardBadgeModelTests: XCTestCase {
    func testNoTalkHistoryUsesFallbackTexts() {
        let model = EpisodeCardBadgeModel.make(
            talkedCount: 0,
            latestTalkedAt: nil
        )

        XCTAssertEqual(model.talkedCountText, "0回")
        XCTAssertEqual(model.latestTalkedAtText, "-")
    }

    func testLatestTalkedAtUsesDateFormat() throws {
        let date = try XCTUnwrap(
            Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 2, day: 25))
        )

        let model = EpisodeCardBadgeModel.make(
            talkedCount: 1,
            latestTalkedAt: date
        )

        XCTAssertEqual(model.latestTalkedAtText, "2026/02/25")
    }
}
