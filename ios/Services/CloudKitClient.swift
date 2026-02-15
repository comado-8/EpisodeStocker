import CloudKit
import Foundation

protocol CloudKitClient {
    func accountStatus() async throws -> CKAccountStatus
}

struct DefaultCloudKitClient: CloudKitClient {
    func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            CKContainer.default().accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: status)
            }
        }
    }
}
