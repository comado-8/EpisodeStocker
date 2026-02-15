import CloudKit
import XCTest
@testable import EpisodeStocker

@MainActor
final class CloudKitBackupServiceTests: XCTestCase {
    func testAvailabilityMapsAvailableToAvailable() async {
        let service = CloudKitBackupService(
            cloudKitClient: FakeCloudKitClient(result: .success(.available)),
            settingsRepository: InMemorySettingsRepository(),
            backupJobRunner: FakeBackupJobRunner(result: .success(()))
        )

        let availability = await service.availability()

        XCTAssertEqual(availability, .available)
    }

    func testAvailabilityMapsNoAccountToUnavailable() async {
        let service = CloudKitBackupService(
            cloudKitClient: FakeCloudKitClient(result: .success(.noAccount)),
            settingsRepository: InMemorySettingsRepository(),
            backupJobRunner: FakeBackupJobRunner(result: .success(()))
        )

        let availability = await service.availability()

        XCTAssertEqual(availability, .unavailable(reason: "iCloudにサインインしてください。"))
    }

    func testAvailabilityMapsTemporarilyUnavailableToMessage() async {
        let service = CloudKitBackupService(
            cloudKitClient: FakeCloudKitClient(result: .success(.temporarilyUnavailable)),
            settingsRepository: InMemorySettingsRepository(),
            backupJobRunner: FakeBackupJobRunner(result: .success(()))
        )

        let availability = await service.availability()

        XCTAssertEqual(availability, .unavailable(reason: "iCloudが一時的に利用できません。"))
    }

    func testAvailabilityMapsCouldNotDetermineToMessage() async {
        let service = CloudKitBackupService(
            cloudKitClient: FakeCloudKitClient(result: .success(.couldNotDetermine)),
            settingsRepository: InMemorySettingsRepository(),
            backupJobRunner: FakeBackupJobRunner(result: .success(()))
        )

        let availability = await service.availability()

        XCTAssertEqual(availability, .unavailable(reason: "iCloudの状態を確認できません。"))
    }

    func testAvailabilityMapsClientErrorToGenericMessage() async {
        let service = CloudKitBackupService(
            cloudKitClient: FakeCloudKitClient(result: .failure(TestError.failed)),
            settingsRepository: InMemorySettingsRepository(),
            backupJobRunner: FakeBackupJobRunner(result: .success(()))
        )

        let availability = await service.availability()

        XCTAssertEqual(availability, .unavailable(reason: "iCloudの状態確認に失敗しました。"))
    }

    func testSetBackupEnabledPersistsState() throws {
        let settings = InMemorySettingsRepository()
        let service = CloudKitBackupService(
            cloudKitClient: FakeCloudKitClient(result: .success(.available)),
            settingsRepository: settings,
            backupJobRunner: FakeBackupJobRunner(result: .success(()))
        )

        try service.setBackupEnabled(true)
        XCTAssertTrue(service.isBackupEnabled())
        try service.setBackupEnabled(false)
        XCTAssertFalse(service.isBackupEnabled())
    }

    func testLastBackupAtReturnsStoredDate() {
        let settings = InMemorySettingsRepository()
        let expectedDate = Date(timeIntervalSince1970: 80_000)
        settings.set(expectedDate, for: .cloudBackupLastRunAt)
        let service = CloudKitBackupService(
            cloudKitClient: FakeCloudKitClient(result: .success(.available)),
            settingsRepository: settings,
            backupJobRunner: FakeBackupJobRunner(result: .success(()))
        )

        XCTAssertEqual(service.lastBackupAt(), expectedDate)
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
            XCTAssertEqual(error, .backupDisabled)
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

    func testRunManualBackupPassesThroughCloudBackupErrorFromRunner() async {
        let settings = InMemorySettingsRepository()
        settings.set(true, for: .cloudBackupEnabled)
        let service = CloudKitBackupService(
            cloudKitClient: FakeCloudKitClient(result: .success(.available)),
            settingsRepository: settings,
            backupJobRunner: FakeBackupJobRunner(result: .failure(CloudBackupError.failed(reason: "runner failed")))
        )

        do {
            _ = try await service.runManualBackup()
            XCTFail("Expected error")
        } catch let error as CloudBackupError {
            XCTAssertEqual(error, .failed(reason: "runner failed"))
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
