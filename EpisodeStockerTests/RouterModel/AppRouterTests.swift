import XCTest
@testable import EpisodeStocker

@MainActor
final class AppRouterTests: XCTestCase {
    func testPushAppendsRoute() {
        let router = AppRouter()

        router.push(.newEpisode)
        router.push(.episodeDetail(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!))

        XCTAssertEqual(router.path.count, 2)
    }

    func testPopRemovesLastRoute() {
        let router = AppRouter()
        let episodeId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        router.push(.newEpisode)
        router.push(.episodeDetail(episodeId))

        router.pop()

        XCTAssertEqual(router.path.count, 1)
        XCTAssertEqual(router.path.first, .newEpisode)
    }

    func testPopOnEmptyPathKeepsPathEmpty() {
        let router = AppRouter()

        router.pop()

        XCTAssertTrue(router.path.isEmpty)
    }
}
