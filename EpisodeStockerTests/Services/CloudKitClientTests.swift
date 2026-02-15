import CloudKit
import XCTest
@testable import EpisodeStocker

final class CloudKitClientTests: XCTestCase {
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
