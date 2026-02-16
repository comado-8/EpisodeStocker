import CloudKit
import XCTest
@testable import EpisodeStocker

final class CloudKitClientTests: XCTestCase {
    func testTimeoutErrorDescriptionIsLocalized() {
        XCTAssertEqual(
            CloudKitClientError.timeout.errorDescription,
            "iCloudアカウント状態の取得がタイムアウトしました。"
        )
    }

    func testAccountStatusResumesOnlyOnceWhenCompletionIsCalledTwice() async throws {
        let client = DefaultCloudKitClient { completion in
            completion(.available, nil)
            completion(.noAccount, nil)
        }

        let status = try await client.accountStatus()

        XCTAssertEqual(status, .available)
    }

    func testAccountStatusTimesOutWhenCompletionIsNeverCalled() async {
        let client = DefaultCloudKitClient(
            fetchAccountStatus: { _ in },
            timeoutNanoseconds: 10_000_000
        )

        do {
            _ = try await client.accountStatus()
            XCTFail("Expected timeout error")
        } catch let error as CloudKitClientError {
            XCTAssertEqual(error, .timeout)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLateCompletionAfterTimeoutDoesNotResumeTwice() async {
        let client = DefaultCloudKitClient(
            fetchAccountStatus: { completion in
                Task {
                    try? await Task.sleep(nanoseconds: 30_000_000)
                    completion(.available, nil)
                }
            },
            timeoutNanoseconds: 5_000_000
        )

        do {
            _ = try await client.accountStatus()
            XCTFail("Expected timeout error")
        } catch let error as CloudKitClientError {
            XCTAssertEqual(error, .timeout)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Wait for delayed completion to execute and ensure no crash/double-resume occurs.
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    func testAccountStatusReturnsProvidedStatus() async throws {
        let client = DefaultCloudKitClient { completion in
            completion(.available, nil)
        }

        let status = try await client.accountStatus()

        XCTAssertEqual(status, .available)
    }

    func testAccountStatusThrowsProvidedError() async {
        let client = DefaultCloudKitClient { completion in
            completion(.couldNotDetermine, TestError.failed)
        }

        do {
            _ = try await client.accountStatus()
            XCTFail("Expected error")
        } catch let error as TestError {
            XCTAssertEqual(error, .failed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private enum TestError: Error, Equatable {
    case failed
}
