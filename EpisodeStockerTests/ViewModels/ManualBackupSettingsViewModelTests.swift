import Foundation
import XCTest
@testable import EpisodeStocker

@MainActor
final class ManualBackupSettingsViewModelTests: XCTestCase {
    func testExportBackupRequiresMatchingConfirmation() async {
        let settings = InMemoryManualBackupSettingsRepository()
        let service = FakeManualBackupService()
        let viewModel = ManualBackupSettingsViewModel(
            manualBackupService: service,
            settingsRepository: settings
        )

        let output = await viewModel.exportBackup(
            passphrase: "passphrase-123",
            confirmation: "different"
        )

        XCTAssertNil(output)
        XCTAssertEqual(viewModel.errorMessage, "確認用パスフレーズが一致しません。")
        XCTAssertFalse(service.didCallExport)
    }

    func testExportBackupSuccessUpdatesTimestampAndReturnsURL() async {
        let settings = InMemoryManualBackupSettingsRepository()
        let expectedDate = Date(timeIntervalSince1970: 123)
        let expectedURL = URL(fileURLWithPath: "/tmp/sample.esbackup")
        let service = FakeManualBackupService(
            exportHandler: { _ in
                settings.set(expectedDate, for: .manualBackupLastExportAt)
                return expectedURL
            }
        )

        let viewModel = ManualBackupSettingsViewModel(
            manualBackupService: service,
            settingsRepository: settings
        )

        let output = await viewModel.exportBackup(
            passphrase: "passphrase-123",
            confirmation: "passphrase-123"
        )

        XCTAssertEqual(output, expectedURL)
        XCTAssertEqual(viewModel.lastExportAt, expectedDate)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testInspectAndRestoreFlow() async {
        let settings = InMemoryManualBackupSettingsRepository()
        let preview = ManualBackupPreview(
            manifest: ManualBackupManifest(schemaVersion: 1, createdAt: Date(timeIntervalSince1970: 100), appVersion: "1.0.0"),
            episodeCount: 1,
            unlockLogCount: 2,
            tagCount: 3,
            personCount: 4,
            projectCount: 5,
            emotionCount: 6,
            placeCount: 7
        )
        let restoredAt = Date(timeIntervalSince1970: 999)
        let url = URL(fileURLWithPath: "/tmp/restore.esbackup")

        let service = FakeManualBackupService(
            inspectHandler: { _, _ in preview },
            restoreHandler: { _, _ in
                settings.set(restoredAt, for: .manualBackupLastRestoreAt)
                return ManualRestoreResult(restoredAt: restoredAt, preview: preview)
            }
        )

        let viewModel = ManualBackupSettingsViewModel(
            manualBackupService: service,
            settingsRepository: settings
        )

        let inspected = await viewModel.inspectBackup(at: url, passphrase: "passphrase-123")
        XCTAssertTrue(inspected)
        XCTAssertEqual(viewModel.pendingRestorePreview, preview)

        let restoreResult = await viewModel.restorePendingBackup()
        XCTAssertEqual(restoreResult?.restoredAt, restoredAt)
        XCTAssertEqual(viewModel.lastRestoreAt, restoredAt)
        XCTAssertNil(viewModel.pendingRestorePreview)
        XCTAssertNil(viewModel.errorMessage)
    }
}

private final class FakeManualBackupService: ManualBackupService {
    private let exportHandler: (String) async throws -> URL
    private let inspectHandler: (URL, String) async throws -> ManualBackupPreview
    private let restoreHandler: (URL, String) async throws -> ManualRestoreResult

    private(set) var didCallExport = false

    init(
        exportHandler: @escaping (String) async throws -> URL = { _ in
            URL(fileURLWithPath: "/tmp/default.esbackup")
        },
        inspectHandler: @escaping (URL, String) async throws -> ManualBackupPreview = { _, _ in
            ManualBackupPreview(
                manifest: ManualBackupManifest(schemaVersion: 1, createdAt: Date(), appVersion: nil),
                episodeCount: 0,
                unlockLogCount: 0,
                tagCount: 0,
                personCount: 0,
                projectCount: 0,
                emotionCount: 0,
                placeCount: 0
            )
        },
        restoreHandler: @escaping (URL, String) async throws -> ManualRestoreResult = { _, _ in
            ManualRestoreResult(
                restoredAt: Date(),
                preview: ManualBackupPreview(
                    manifest: ManualBackupManifest(schemaVersion: 1, createdAt: Date(), appVersion: nil),
                    episodeCount: 0,
                    unlockLogCount: 0,
                    tagCount: 0,
                    personCount: 0,
                    projectCount: 0,
                    emotionCount: 0,
                    placeCount: 0
                )
            )
        }
    ) {
        self.exportHandler = exportHandler
        self.inspectHandler = inspectHandler
        self.restoreHandler = restoreHandler
    }

    func exportEncryptedBackup(passphrase: String) async throws -> URL {
        didCallExport = true
        return try await exportHandler(passphrase)
    }

    func inspectEncryptedBackup(at url: URL, passphrase: String) async throws -> ManualBackupPreview {
        try await inspectHandler(url, passphrase)
    }

    func restoreEncryptedBackup(at url: URL, passphrase: String) async throws -> ManualRestoreResult {
        try await restoreHandler(url, passphrase)
    }
}

private final class InMemoryManualBackupSettingsRepository: SettingsRepository {
    private var boolStorage: [SettingsKey: Bool] = [:]
    private var dateStorage: [SettingsKey: Date] = [:]

    func bool(for key: SettingsKey) -> Bool {
        boolStorage[key] ?? false
    }

    func set(_ value: Bool, for key: SettingsKey) {
        boolStorage[key] = value
    }

    func optionalBool(for key: SettingsKey) -> Bool? {
        boolStorage[key]
    }

    func setOptionalBool(_ value: Bool?, for key: SettingsKey) {
        boolStorage[key] = value
    }

    func date(for key: SettingsKey) -> Date? {
        dateStorage[key]
    }

    func set(_ value: Date?, for key: SettingsKey) {
        dateStorage[key] = value
    }
}
