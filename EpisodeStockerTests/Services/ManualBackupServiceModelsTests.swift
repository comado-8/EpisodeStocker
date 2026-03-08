import Foundation
import XCTest
@testable import EpisodeStocker

final class ManualBackupServiceModelsTests: XCTestCase {
    func testManualBackupPreviewTotalRecordCountSumsAllCounts() {
        let preview = ManualBackupPreview(
            manifest: ManualBackupManifest(
                schemaVersion: 1,
                createdAt: Date(timeIntervalSince1970: 1_234),
                appVersion: "1.0.0"
            ),
            episodeCount: 1,
            unlockLogCount: 2,
            tagCount: 3,
            personCount: 4,
            projectCount: 5,
            emotionCount: 6,
            placeCount: 7
        )

        XCTAssertEqual(preview.totalRecordCount, 28)
    }

    func testManualBackupErrorLocalizedDescriptionCoversAllCases() {
        let errors: [ManualBackupError] = [
            .invalidPassphrase,
            .invalidFormat,
            .unsupportedVersion(2),
            .wrongPassphrase,
            .decryptFailed,
            .encryptFailed,
            .fileReadFailed,
            .fileWriteFailed,
            .validationFailed(reason: "bad refs"),
            .restoreFailed(reason: "db error")
        ]

        let descriptions = errors.map(\.localizedDescription)

        XCTAssertTrue(descriptions.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(descriptions[0], "パスフレーズは8文字以上で入力してください。")
        XCTAssertTrue(descriptions[2].contains("version: 2"))
        XCTAssertTrue(descriptions[8].contains("bad refs"))
        XCTAssertTrue(descriptions[9].contains("db error"))
    }
}
