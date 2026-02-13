import SwiftData
import XCTest
@testable import EpisodeStocker

@MainActor
final class SeedDataTests: XCTestCase {
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

    func testSeedIfNeededInsertsSampleEpisodeWhenEmpty() throws {
        SeedData.seedIfNeeded(context: context)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 1)
        XCTAssertTrue(episodes[0].title.contains("初期サンプル"))
    }

    func testSeedIfNeededDoesNotInsertDuplicates() throws {
        SeedData.seedIfNeeded(context: context)
        SeedData.seedIfNeeded(context: context)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 1)
    }
}
