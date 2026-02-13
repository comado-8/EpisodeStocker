import Foundation
import SwiftUI

@MainActor
final class EpisodeStore: ObservableObject {
    @Published private(set) var episodes: [Episode] = []
    @Published private(set) var tags: [Tag] = []

    init() {
        seed()
    }

    func addEpisode(title: String, body: String?, status: EpisodeStatus) {
        let now = Date()
        let episode = Episode(
            id: UUID(),
            title: title,
            body: body,
            tags: [],
            status: status,
            category: nil,
            createdAt: now,
            updatedAt: now,
            histories: nil
        )
        episodes.insert(episode, at: 0)
    }

    func episode(id: UUID) -> Episode? {
        episodes.first(where: { $0.id == id })
    }

    private func seed() {
        let sampleTag = Tag(id: UUID(), name: "仕事", color: nil, usageCount: 1)
        tags = [sampleTag]
        let sample = Episode(
            id: UUID(),
            title: "初期サンプル: 収録前の出来事",
            body: "収録直前に起きた小ネタをここに書く",
            tags: [sampleTag.id],
            status: .unpublished,
            category: "仕事",
            createdAt: Date(),
            updatedAt: Date(),
            histories: nil
        )
        episodes = [sample]
    }
}
