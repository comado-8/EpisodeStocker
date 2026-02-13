import XCTest
@testable import EpisodeStocker

@MainActor
final class PersistenceNormalizationTests: XCTestCase {
    func testNormalizeNameTrimsAndLowercases() {
        let result = EpisodePersistence.normalizeName("  HeLLo World  ")
        XCTAssertEqual(result?.name, "HeLLo World")
        XCTAssertEqual(result?.normalized, "hello world")
    }

    func testNormalizeNameReturnsNilForEmptyInput() {
        XCTAssertNil(EpisodePersistence.normalizeName("   \n\t  "))
    }

    func testNormalizeTagNameRemovesLeadingHashTrimsAndLowercases() {
        let result = EpisodePersistence.normalizeTagName("  #TaG Name  ")
        XCTAssertEqual(result?.name, "TaG Name")
        XCTAssertEqual(result?.normalized, "tag name")
    }

    func testNormalizeTagNameReturnsNilWhenOnlyHash() {
        XCTAssertNil(EpisodePersistence.normalizeTagName("   #   "))
    }
}
