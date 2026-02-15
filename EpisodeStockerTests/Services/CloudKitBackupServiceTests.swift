import CloudKit
import XCTest
@testable import EpisodeStocker

@MainActor
final class CloudKitBackupServiceTests: XCTestCase {
    func testAvailabilityMapsNoAccountToUnavailable() async {
        let service = CloudKitBackupService(
            cloudKitClient: FakeCloudKitClient(result: .success(.noAccount)),
            settingsRepository: InMemorySettingsRepository(),
            backupJobRunner: FakeBackupJobRunner(result: .success(()))
        )

        let availability = await service.availability()

        XCTAssertEqual(availability, .unavailable(reason: "iCloudにサインインしてください。"))
    }

    func testRunManualBackupStoresLastRunDate() async throws {
        let settings = InMemorySettingsRepository()
        settings.set(true, for: .cloudBackupEnabled)
        let expectedDate = Date(timeIntervalSince1970: 54_321)
        let service = CloudKitBackupService(
            cloudKitClient: FakeCloudKitClient(result: .success(.available)),
            settingsRepository: settings,
            backupJobRunner: FakeBackupJobRunner(result: .success(())),
            now: { expectedDate }
        )

        let actual = try await service.runManualBackup()

        XCTAssertEqual(actual, expectedDate)
        XCTAssertEqual(settings.date(for: .cloudBackupLastRunAt), expectedDate)
    }

    func testRunManualBackupThrowsUnavailableWhenCloudKitUnavailable() async {
        let settings = InMemorySettingsRepository()
        settings.set(true, for: .cloudBackupEnabled)
        let service = CloudKitBackupService(
            cloudKitClient: FakeCloudKitClient(result: .success(.restricted)),
            settingsRepository: settings,
            backupJobRunner: FakeBackupJobRunner(result: .success(()))
        )

        do {
            _ = try await service.runManualBackup()
            XCTFail("Expected error")
        } catch let error as CloudBackupError {
            XCTAssertEqual(error, .unavailable(reason: "このデバイスではiCloudが制限されています。"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRunManualBackupThrowsWhenBackupDisabled() async {
        let settings = InMemorySettingsRepository()
        settings.set(false, for: .cloudBackupEnabled)
        let service = CloudKitBackupService(
            cloudKitClient: FakeCloudKitClient(result: .success(.available)),
            settingsRepository: settings,
            backupJobRunner: FakeBackupJobRunner(result: .success(()))
        )

        do {
            _ = try await service.runManualBackup()
            XCTFail("Expected error")
        } catch let error as CloudBackupError {
            XCTAssertEqual(error, .failed(reason: "クラウドバックアップがオフです。"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRunManualBackupMapsRunnerFailure() async {
        let settings = InMemorySettingsRepository()
        settings.set(true, for: .cloudBackupEnabled)
        let service = CloudKitBackupService(
            cloudKitClient: FakeCloudKitClient(result: .success(.available)),
            settingsRepository: settings,
            backupJobRunner: FakeBackupJobRunner(result: .failure(TestError.failed))
        )

        do {
            _ = try await service.runManualBackup()
            XCTFail("Expected error")
        } catch let error as CloudBackupError {
            XCTAssertEqual(error, .failed(reason: "バックアップの実行に失敗しました。"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private enum TestError: Error {
    case failed
}

private final class FakeCloudKitClient: CloudKitClient {
    private let result: Result<CKAccountStatus, Error>

    init(result: Result<CKAccountStatus, Error>) {
        self.result = result
    }

    func accountStatus() async throws -> CKAccountStatus {
        try result.get()
    }
}

private final class FakeBackupJobRunner: CloudBackupJobRunner {
    private let result: Result<Void, Error>

    init(result: Result<Void, Error>) {
        self.result = result
    }

    func runBackupRequest() async throws {
        _ = try result.get()
    }
}

private final class InMemorySettingsRepository: SettingsRepository {
    private var boolStorage: [SettingsKey: Bool] = [:]
    private var dateStorage: [SettingsKey: Date] = [:]

    func bool(for key: SettingsKey) -> Bool {
        boolStorage[key] ?? false
    }

    func set(_ value: Bool, for key: SettingsKey) {
        boolStorage[key] = value
    }

    func date(for key: SettingsKey) -> Date? {
        dateStorage[key]
    }

    func set(_ value: Date?, for key: SettingsKey) {
        dateStorage[key] = value
    }
}
