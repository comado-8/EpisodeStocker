import Foundation
import SwiftData

@MainActor
enum SeedData {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Episode>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        let now = Date()
        let tag = context.upsertTag(name: "仕事")
        let episode = Episode(
            date: now,
            title: "初期サンプル: 収録前の出来事",
            body: "収録直前に起きた小ネタをここに書く",
            unlockDate: nil,
            type: nil,
            createdAt: now,
            updatedAt: now
        )
        if let tag {
            episode.tags = [tag]
        }
        context.insert(episode)
        try? context.save()
    }
}
