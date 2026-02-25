import XCTest
@testable import EpisodeStocker

@MainActor
final class PersistenceNormalizationTests: XCTestCase {
    func testStripLeadingTagPrefixRemovesAsciiAndFullwidthHashes() {
        XCTAssertEqual(EpisodePersistence.stripLeadingTagPrefix("  # ＃ #  タグ  "), "タグ")
        XCTAssertEqual(EpisodePersistence.stripLeadingTagPrefix("  ＃＃#Tag"), "Tag")
        XCTAssertEqual(EpisodePersistence.stripLeadingTagPrefix("NoPrefix"), "NoPrefix")
    }

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
        XCTAssertEqual(result?.name, "tagname")
        XCTAssertEqual(result?.normalized, "tagname")
    }

    func testNormalizeTagNameReturnsNilWhenOnlyHash() {
        XCTAssertNil(EpisodePersistence.normalizeTagName("   #   "))
        XCTAssertNil(EpisodePersistence.normalizeTagName("###"))
        XCTAssertNil(EpisodePersistence.normalizeTagName("  ＃＃＃  "))
    }

    func testNormalizeTagNameSupportsFullwidthHashPrefix() {
        let result = EpisodePersistence.normalizeTagName("  ＃＃TaG Name  ")
        XCTAssertEqual(result?.name, "tagname")
        XCTAssertEqual(result?.normalized, "tagname")
    }

    func testNormalizeTagNameRemovesAllWhitespaces() {
        let result = EpisodePersistence.normalizeTagName("  # T a　g \n Name \t ")
        XCTAssertEqual(result?.name, "tagname")
        XCTAssertEqual(result?.normalized, "tagname")
    }

    func testNormalizeTagNameAppliesNFKC() {
        let result = EpisodePersistence.normalizeTagName("＃Ｔｅｓｔ１２３")
        XCTAssertEqual(result?.name, "test123")
        XCTAssertEqual(result?.normalized, "test123")
    }

    func testValidateTagNameInputReturnsEmptyAfterNormalization() {
        XCTAssertEqual(EpisodePersistence.validateTagNameInput("###"), .empty)
        XCTAssertEqual(EpisodePersistence.validateTagNameInput(" ＃ ＃ "), .empty)
    }

    func testValidateTagNameInputReturnsTooLong() {
        let tooLong = String(repeating: "a", count: 21)
        XCTAssertEqual(EpisodePersistence.validateTagNameInput(tooLong), .tooLong(limit: 20))
    }

    func testValidateTagNameInputReturnsContainsDisallowedCharacters() {
        XCTAssertEqual(
            EpisodePersistence.validateTagNameInput("tag name"),
            .containsDisallowedCharacters
        )
        XCTAssertEqual(
            EpisodePersistence.validateTagNameInput("tag!"),
            .containsDisallowedCharacters
        )
        XCTAssertEqual(
            EpisodePersistence.validateTagNameInput("tag🙂"),
            .containsDisallowedCharacters
        )
    }

    func testValidateTagNameInputReturnsValidForJapaneseAndAlphanumeric() {
        let result = EpisodePersistence.validateTagNameInput("＃仕事2026")
        XCTAssertEqual(result, .valid(name: "仕事2026"))

        let katakana = EpisodePersistence.validateTagNameInput("#ユーザー")
        XCTAssertEqual(katakana, .valid(name: "ユーザー"))

        let english = EpisodePersistence.validateTagNameInput("#TaG")
        XCTAssertEqual(english, .valid(name: "tag"))
    }

    func testNormalizeTagInputWhileEditingAppliesNFKCAndLowercase() {
        XCTAssertEqual(
            EpisodePersistence.normalizeTagInputWhileEditing("ＴｅＳｔ１２３"),
            "test123"
        )
    }

    func testNormalizeNameInputReturnsTrimmedValueWithinLimit() {
        XCTAssertEqual(EpisodePersistence.normalizeNameInput("  Alice  ", limit: 5), "Alice")
    }

    func testNormalizeNameInputReturnsNilWhenEmptyOrOverLimit() {
        XCTAssertNil(EpisodePersistence.normalizeNameInput("   \n\t", limit: 5))
        XCTAssertNil(EpisodePersistence.normalizeNameInput("TooLong", limit: 5))
    }

    func testClampBodyTextDoesNotChangeWhenWithinLimit() {
        let withinLimit = String(repeating: "a", count: 800)
        XCTAssertEqual(EpisodePersistence.clampBodyText(withinLimit), withinLimit)
    }

    func testClampBodyTextTruncatesWhenOverLimit() {
        let overLimit = String(repeating: "b", count: 801)
        let clamped = EpisodePersistence.clampBodyText(overLimit)
        XCTAssertEqual(clamped.count, 800)
        XCTAssertEqual(clamped, String(repeating: "b", count: 800))
    }

    func testClampBodyTextSupportsJapaneseAndEmoji() {
        let input = String(repeating: "あ", count: 799) + "🙂🙂"
        let clamped = EpisodePersistence.clampBodyText(input)
        XCTAssertEqual(clamped.count, 800)
        XCTAssertTrue(clamped.hasSuffix("🙂"))
        XCTAssertFalse(clamped.hasSuffix("🙂🙂"))
    }

    func testEmotionPresetOptionsAreFixedFifteenValues() {
        XCTAssertEqual(
            EpisodePersistence.emotionPresetOptions,
            [
                "楽しい",
                "嬉しい",
                "ワクワク",
                "安心",
                "達成感",
                "感謝",
                "緊張",
                "不安",
                "辛い",
                "悔しい",
                "悲しい",
                "怒り",
                "驚き",
                "困惑",
                "集中",
            ]
        )
    }
}
