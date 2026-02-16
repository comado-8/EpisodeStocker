import CloudKit
import Foundation

protocol CloudKitClient {
    func accountStatus() async throws -> CKAccountStatus
}

enum CloudKitClientError: LocalizedError, Equatable {
    case timeout

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "iCloudアカウント状態の取得がタイムアウトしました。"
        }
    }
}

struct DefaultCloudKitClient: CloudKitClient {
    private static let defaultTimeoutNanoseconds: UInt64 = 5_000_000_000

    private let fetchAccountStatus: (@escaping (CKAccountStatus, Error?) -> Void) -> Void
    private let timeoutNanoseconds: UInt64

    init(
        fetchAccountStatus: @escaping (@escaping (CKAccountStatus, Error?) -> Void) -> Void = { completion in
            Task {
                do { completion(try await CKContainer.default().accountStatus(), nil) }
                catch { completion(.couldNotDetermine, error) }
            }
        },
        timeoutNanoseconds: UInt64 = DefaultCloudKitClient.defaultTimeoutNanoseconds
    ) {
        self.fetchAccountStatus = fetchAccountStatus
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            let resumeGate = ContinuationResumeGate(continuation: continuation)

            fetchAccountStatus { status, error in
                if let error {
                    resumeGate.resume(with: .failure(error))
                    return
                }
                resumeGate.resume(with: .success(status))
            }

            Task {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                resumeGate.resume(with: .failure(CloudKitClientError.timeout))
            }
        }
    }
}

private final class ContinuationResumeGate<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<T, Error>) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }
}
