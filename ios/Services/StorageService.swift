import Foundation

actor StorageService {
    func save(_ episodes: [Episode]) async throws {
        // SwiftData へ移行したため永続化は ModelContext 側で行う。
        // 互換のために空実装を残す。
        _ = episodes
    }

    func load() async throws -> [Episode]? {
        // SwiftData へ移行したため永続化は ModelContext 側で行う。
        return nil
    }
}
