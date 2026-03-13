import Foundation
import SwiftData

@MainActor
final class CloudSyncDataPreparationService {
    private let modelContext: ModelContext
    private let settingsRepository: SettingsRepository
    private let now: () -> Date

    init(
        modelContext: ModelContext,
        settingsRepository: SettingsRepository = UserDefaultsSettingsRepository(),
        now: @escaping () -> Date = Date.init
    ) {
        self.modelContext = modelContext
        self.settingsRepository = settingsRepository
        self.now = now
    }

    func prepareIfNeeded() {
        guard !settingsRepository.bool(for: .cloudSyncMigrationPrepared) else { return }

        do {
            try deduplicateNamedEntities(Tag.self, relation: \Episode.tags)
            try deduplicateNamedEntities(Person.self, relation: \Episode.persons)
            try deduplicateNamedEntities(Project.self, relation: \Episode.projects)
            try deduplicateNamedEntities(Emotion.self, relation: \Episode.emotions)
            try deduplicateNamedEntities(Place.self, relation: \Episode.places)
            try normalizeEpisodeRelationships()
            try removeOrphanUnlockLogs()
            try modelContext.save()
            settingsRepository.set(true, for: .cloudSyncMigrationPrepared)
            settingsRepository.set(false, for: .cloudSyncRuntimeDisabled)
        } catch {
            settingsRepository.set(false, for: .cloudSyncMigrationPrepared)
            NSLog("Cloud sync data preparation failed: %@", String(describing: error))
        }
    }

    private func normalizeEpisodeRelationships() throws {
        let episodes = try modelContext.fetch(FetchDescriptor<Episode>())
        for episode in episodes {
            episode.tags = uniqueByID(episode.tags)
            episode.persons = uniqueByID(episode.persons)
            episode.projects = uniqueByID(episode.projects)
            episode.emotions = uniqueByID(episode.emotions)
            episode.places = uniqueByID(episode.places)
            episode.unlockLogs = uniqueByID(episode.unlockLogs).filter { $0.episodeOrNil?.id == episode.id }
            episode.updatedAt = now()
        }
    }

    private func removeOrphanUnlockLogs() throws {
        let logs = try modelContext.fetch(FetchDescriptor<UnlockLog>())
        for log in logs {
            guard let episode = log.episodeOrNil else {
                modelContext.delete(log)
                continue
            }
            if !episode.unlockLogs.contains(where: { $0.id == log.id }) {
                var logs = episode.unlockLogs
                logs.append(log)
                episode.unlockLogs = uniqueByID(logs)
                episode.updatedAt = now()
            }
        }
    }

    private func deduplicateNamedEntities<Entity: CloudSyncNameEntity>(
        _: Entity.Type,
        relation: ReferenceWritableKeyPath<Episode, [Entity]>
    ) throws {
        let entities = try modelContext.fetch(FetchDescriptor<Entity>())
        let grouped = Dictionary(grouping: entities) { entity in
            canonicalNormalizedKey(current: entity.nameNormalized, fallbackName: entity.name)
        }

        for group in grouped.values where group.count > 1 {
            let sorted = group.sorted(by: shouldPrioritize)
            guard let survivor = sorted.first else { continue }

            survivor.nameNormalized = canonicalNormalizedKey(
                current: survivor.nameNormalized,
                fallbackName: survivor.name
            )
            if survivor.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                survivor.name = survivor.nameNormalized
            }

            for duplicate in sorted.dropFirst() {
                mergeEpisodes(from: duplicate, into: survivor, relation: relation)
                modelContext.delete(duplicate)
            }

            survivor.updatedAt = now()
        }
    }

    private func mergeEpisodes<Entity: CloudSyncNameEntity>(
        from duplicate: Entity,
        into survivor: Entity,
        relation: ReferenceWritableKeyPath<Episode, [Entity]>
    ) {
        for episode in duplicate.episodes {
            var relations = episode[keyPath: relation].filter { $0.id != duplicate.id }
            if !relations.contains(where: { $0.id == survivor.id }) {
                relations.append(survivor)
            }
            episode[keyPath: relation] = uniqueByID(relations)
            episode.updatedAt = now()
        }
    }

    private func shouldPrioritize<Entity: CloudSyncNameEntity>(_ lhs: Entity, _ rhs: Entity) -> Bool {
        if lhs.isSoftDeleted != rhs.isSoftDeleted {
            return !lhs.isSoftDeleted
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func canonicalNormalizedKey(current: String, fallbackName: String) -> String {
        let trimmedCurrent = current.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmedCurrent.isEmpty {
            return trimmedCurrent
        }
        return fallbackName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func uniqueByID<Model: CloudSyncIdentifiable>(_ values: [Model]) -> [Model] {
        var seen = Set<UUID>()
        var result: [Model] = []
        for value in values {
            if seen.insert(value.id).inserted {
                result.append(value)
            }
        }
        return result
    }
}

private protocol CloudSyncIdentifiable {
    var id: UUID { get }
}

private protocol CloudSyncNameEntity: PersistentModel, CloudSyncIdentifiable {
    var name: String { get set }
    var nameNormalized: String { get set }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var isSoftDeleted: Bool { get set }
    var episodes: [Episode] { get set }
}

extension Tag: CloudSyncNameEntity {}
extension Person: CloudSyncNameEntity {}
extension Project: CloudSyncNameEntity {}
extension Emotion: CloudSyncNameEntity {}
extension Place: CloudSyncNameEntity {}
extension UnlockLog: CloudSyncIdentifiable {}
