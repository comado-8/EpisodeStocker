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
}
