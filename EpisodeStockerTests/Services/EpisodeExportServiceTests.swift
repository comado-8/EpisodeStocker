import CoreGraphics
import Foundation
import XCTest
@testable import EpisodeStocker

@MainActor
final class EpisodeExportServiceTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EpisodeExportServiceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testTXTExportUsesEpisodeDateLabelAndEpisodeDateValue() throws {
        let service = makeService(now: makeDate(2026, 3, 5))
        let episode = Episode(
            date: makeDate(2026, 3, 1),
            title: "エピソードタイトル",
            body: "本文テキスト",
            unlockDate: makeDate(2099, 1, 1)
        )

        let url = try service.export(format: .txt, episode: episode)
        let text = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(text.contains("# エピソードタイトル"))
        XCTAssertTrue(text.contains("本文テキスト"))
        XCTAssertTrue(text.contains("エピソード日付: 2026/03/01"))
        XCTAssertTrue(text.contains("解禁可能日: 2099/01/01"))
        XCTAssertTrue(text.contains("ステータス: 解禁前"))
        XCTAssertFalse(text.contains("登録日:"))
    }

    func testSanitizedFilenameReplacesForbiddenCharactersAndTruncates() {
        let rawTitle = "a/b:c*d?e\"f<g>h|i1234567890123456789012345678901234567890"
        let sanitized = EpisodeExportService.sanitizeFilenameTitle(rawTitle)

        XCTAssertEqual(sanitized.count, 40)
        XCTAssertFalse(sanitized.contains("/"))
        XCTAssertFalse(sanitized.contains("\\"))
        XCTAssertFalse(sanitized.contains(":"))
        XCTAssertFalse(sanitized.contains("*"))
        XCTAssertFalse(sanitized.contains("?"))
        XCTAssertFalse(sanitized.contains("\""))
        XCTAssertFalse(sanitized.contains("<"))
        XCTAssertFalse(sanitized.contains(">"))
        XCTAssertFalse(sanitized.contains("|"))
    }

    func testMakeFilenameUsesExportDateAndExtension() {
        let service = makeService(now: makeDate(2026, 3, 5))
        let filename = service.makeFilename(format: .txt, title: "sample")

        XCTAssertEqual(filename, "Episode_20260305_sample.txt")
    }

    func testPDFExportGeneratesMultiplePagesForLongBody() throws {
        #if canImport(UIKit)
        let service = makeService(now: makeDate(2026, 3, 5))
        let body = Array(repeating: "長文テキストです。", count: 6_000).joined(separator: "\n")
        let episode = Episode(
            date: makeDate(2026, 3, 1),
            title: "長文テスト",
            body: body,
            unlockDate: nil
        )

        let url = try service.export(format: .pdf, episode: episode)
        let document = try XCTUnwrap(CGPDFDocument(url as CFURL))

        XCTAssertGreaterThan(document.numberOfPages, 1)
        #else
        throw XCTSkip("PDF renderer unsupported on non-UIKit hosts")
        #endif
    }

    func testPDFExportFailsWhenAppIconIsMissing() throws {
        #if canImport(UIKit)
        let renderer = EpisodeExportPDFRenderer(iconProvider: { nil })
        let service = EpisodeExportService(
            fileManager: .default,
            temporaryDirectory: temporaryDirectory,
            now: { self.makeDate(2026, 3, 5) },
            pdfRenderer: renderer
        )
        let episode = Episode(date: makeDate(2026, 3, 1), title: "title", body: "body")

        XCTAssertThrowsError(try service.export(format: .pdf, episode: episode)) { error in
            XCTAssertEqual(error as? EpisodeExportError, .missingAppIcon)
        }
        #else
        throw XCTSkip("PDF export not supported on this platform")
        #endif
    }

    private func makeService(now: Date) -> EpisodeExportService {
        EpisodeExportService(
            fileManager: .default,
            temporaryDirectory: temporaryDirectory,
            now: { now }
        )
    }
}

private extension EpisodeExportServiceTests {
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
