import Foundation

actor StorageService {
    private let key = "episodestocker:episodes"

    func save(_ episodes: [Episode]) async throws {
        let data = try JSONEncoder().encode(episodes)
        UserDefaults.standard.set(data, forKey: key)
    }

    func load() async throws -> [Episode]? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try JSONDecoder().decode([Episode].self, from: data)
    }
}
