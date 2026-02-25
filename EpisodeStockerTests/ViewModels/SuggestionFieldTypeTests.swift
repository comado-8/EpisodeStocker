import XCTest
@testable import EpisodeStocker

final class SuggestionFieldTypeTests: XCTestCase {
  func testInitMapsKnownAndUnknownValues() {
    XCTAssertEqual(SuggestionFieldType("人物"), .person)
    XCTAssertEqual(SuggestionFieldType("企画名"), .project)
    XCTAssertEqual(SuggestionFieldType("感情"), .emotion)
    XCTAssertEqual(SuggestionFieldType("場所"), .place)
    XCTAssertEqual(SuggestionFieldType("タグ"), .tag)
    XCTAssertEqual(SuggestionFieldType("other"), .unknown("other"))
  }

  func testLabelReturnsExpectedStringForEveryCase() {
    XCTAssertEqual(SuggestionFieldType.person.label, "人物")
    XCTAssertEqual(SuggestionFieldType.project.label, "企画名")
    XCTAssertEqual(SuggestionFieldType.emotion.label, "感情")
    XCTAssertEqual(SuggestionFieldType.place.label, "場所")
    XCTAssertEqual(SuggestionFieldType.tag.label, "タグ")
    XCTAssertEqual(SuggestionFieldType.unknown("foo").label, "foo")
  }

  func testSupportsUsageCountFlagByCase() {
    XCTAssertTrue(SuggestionFieldType.person.supportsUsageCount)
    XCTAssertTrue(SuggestionFieldType.project.supportsUsageCount)
    XCTAssertFalse(SuggestionFieldType.emotion.supportsUsageCount)
    XCTAssertTrue(SuggestionFieldType.place.supportsUsageCount)
    XCTAssertTrue(SuggestionFieldType.tag.supportsUsageCount)
    XCTAssertFalse(SuggestionFieldType.unknown("foo").supportsUsageCount)
  }

  func testProtectsUsedEntriesFromDeletionFlagByCase() {
    XCTAssertTrue(SuggestionFieldType.person.protectsUsedEntriesFromDeletion)
    XCTAssertTrue(SuggestionFieldType.project.protectsUsedEntriesFromDeletion)
    XCTAssertFalse(SuggestionFieldType.emotion.protectsUsedEntriesFromDeletion)
    XCTAssertTrue(SuggestionFieldType.place.protectsUsedEntriesFromDeletion)
    XCTAssertTrue(SuggestionFieldType.tag.protectsUsedEntriesFromDeletion)
    XCTAssertFalse(SuggestionFieldType.unknown("foo").protectsUsedEntriesFromDeletion)
  }

  func testRoundtripBetweenInitAndLabelAndUnknownDistinctness() {
    let knownPairs: [(String, SuggestionFieldType)] = [
      ("人物", .person),
      ("企画名", .project),
      ("感情", .emotion),
      ("場所", .place),
      ("タグ", .tag),
    ]
    for (raw, expected) in knownPairs {
      let resolved = SuggestionFieldType(raw)
      XCTAssertEqual(resolved, expected)
      XCTAssertEqual(resolved.label, raw)
    }

    let unknownValues = ["other", "", "人物 ", "TAG"]
    for value in unknownValues {
      let resolved = SuggestionFieldType(value)
      XCTAssertEqual(resolved, .unknown(value))
      XCTAssertEqual(resolved.label, value)
    }

    XCTAssertNotEqual(SuggestionFieldType.unknown("a"), SuggestionFieldType.unknown("b"))
  }
}
