import CloudKit
import Foundation

protocol CloudKitClient {
    func accountStatus() async throws -> CKAccountStatus
}

struct DefaultCloudKitClient: CloudKitClient {
    private let fetchAccountStatus: (@escaping (CKAccountStatus, Error?) -> Void) -> Void

    init(
        fetchAccountStatus: @escaping (@escaping (CKAccountStatus, Error?) -> Void) -> Void = { completion in
            CKContainer.default().accountStatus(completionHandler: completion)
        }
    ) {
        self.fetchAccountStatus = fetchAccountStatus
    }

    func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            fetchAccountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: status)
            }
        }
    }
}
