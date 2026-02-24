import Foundation
import SwiftData

enum TagValidationResult: Equatable {
    case valid(name: String)
    case empty
    case tooLong(limit: Int)
    case containsDisallowedCharacters

    var normalizedName: String? {
        guard case let .valid(name) = self else { return nil }
        return name
    }
}

@MainActor
enum EpisodePersistence {
    private nonisolated static let tagNameLimit = 20
    nonisolated static let bodyCharacterLimit = 800
    nonisolated static let personNameCharacterLimit = 10
    nonisolated static let projectNameCharacterLimit = 20
    nonisolated static let placeNameCharacterLimit = 20
    nonisolated static let emotionPresetOptions: [String] = [
        "楽しい",
        "嬉しい",
        "ワクワク",
        "安心",
        "達成感",
        "感謝",
        "緊張",
        "不安",
        "辛い",
        "悔しい",
        "悲しい",
        "怒り",
        "驚き",
        "困惑",
        "集中",
    ]

    nonisolated static func stripLeadingTagPrefix(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = trimmed.first, first == "#" || first == "＃" {
            trimmed.removeFirst()
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    nonisolated static func normalizeName(_ value: String) -> (name: String, normalized: String)? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return (trimmed, trimmed.lowercased())
    }

    nonisolated static func normalizeTagName(_ value: String) -> (name: String, normalized: String)? {
        let canonical = normalizedTagCandidate(value)
        guard !canonical.isEmpty else { return nil }
        return (canonical, canonical)
    }

    nonisolated static func validateTagNameInput(_ value: String) -> TagValidationResult {
        let strippedPrefix = stripLeadingTagPrefix(value)
        let normalized = applyingNFKC(strippedPrefix)
        let compacted = removingTagWhitespaces(normalized)

        let canonical = compacted.lowercased()

        guard !canonical.isEmpty else { return .empty }
        guard !containsWhitespace(normalized) else { return .containsDisallowedCharacters }
        guard canonical.count <= tagNameLimit else { return .tooLong(limit: tagNameLimit) }
        guard containsOnlyAllowedTagCharacters(canonical) else { return .containsDisallowedCharacters }

        return .valid(name: canonical)
    }

    nonisolated static func normalizeTagInputWhileEditing(_ value: String) -> String {
        applyingNFKC(value).lowercased()
    }

    nonisolated static func clampBodyText(_ value: String, limit: Int = bodyCharacterLimit) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit))
    }

    nonisolated static func normalizeNameInput(
        _ value: String,
        limit: Int
    ) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= limit else { return nil }
        return trimmed
    }

    private nonisolated static func normalizedTagCandidate(_ value: String) -> String {
        let strippedPrefix = stripLeadingTagPrefix(value)
        let normalized = applyingNFKC(strippedPrefix)
        return removingTagWhitespaces(normalized).lowercased()
    }

    private nonisolated static func applyingNFKC(_ value: String) -> String {
        value.precomposedStringWithCompatibilityMapping
    }

    private nonisolated static func removingTagWhitespaces(_ value: String) -> String {
        let scalars = value.unicodeScalars.filter { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar)
        }
        return String(String.UnicodeScalarView(scalars))
    }

    private nonisolated static func containsWhitespace(_ value: String) -> Bool {
        value.unicodeScalars.contains { CharacterSet.whitespacesAndNewlines.contains($0) }
    }

    private nonisolated static func containsOnlyAllowedTagCharacters(_ value: String) -> Bool {
        value.range(
            of: #"^[\p{Hiragana}\p{Katakana}\p{Han}A-Za-z0-9ー]+$"#,
            options: .regularExpression
        ) != nil
    }
}

extension ModelContext {
    @MainActor
    private func saveWithDiagnostics(operation: String) {
        do {
            try save()
        } catch {
            assertionFailure("ModelContext.save failed during \(operation): \(error)")
        }
    }

    @MainActor
    func upsertTag(name: String) -> Tag? {
        guard let info = EpisodePersistence.normalizeTagName(name) else { return nil }
        let normalized = info.normalized
        let descriptor = FetchDescriptor<Tag>()
        if let existing = (try? fetch(descriptor))?.first(where: {
            if $0.nameNormalized == normalized {
                return true
            }
            return EpisodePersistence.normalizeTagName($0.name)?.normalized == normalized
        }) {
            existing.name = info.name
            existing.nameNormalized = info.normalized
            existing.isSoftDeleted = false
            existing.deletedAt = nil
            existing.updatedAt = Date()
            return existing
        }
        let tag = Tag(name: info.name, nameNormalized: info.normalized)
        insert(tag)
        return tag
    }

    @MainActor
    func upsertPerson(name: String) -> Person? {
        guard let info = EpisodePersistence.normalizeName(name) else { return nil }
        let normalized = info.normalized
        let descriptor = FetchDescriptor<Person>()
        if let existing = (try? fetch(descriptor))?.first(where: { $0.nameNormalized == normalized }) {
            existing.name = info.name
            existing.nameNormalized = info.normalized
            if existing.isSoftDeleted {
                existing.isSoftDeleted = false
                existing.deletedAt = nil
            }
            existing.updatedAt = Date()
            return existing
        }
        let person = Person(name: info.name, nameNormalized: info.normalized)
        insert(person)
        return person
    }

    @MainActor
    func upsertProject(name: String) -> Project? {
        guard let info = EpisodePersistence.normalizeName(name) else { return nil }
        let normalized = info.normalized
        let descriptor = FetchDescriptor<Project>()
        if let existing = (try? fetch(descriptor))?.first(where: { $0.nameNormalized == normalized }) {
            existing.name = info.name
            existing.nameNormalized = info.normalized
            if existing.isSoftDeleted {
                existing.isSoftDeleted = false
                existing.deletedAt = nil
            }
            existing.updatedAt = Date()
            return existing
        }
        let project = Project(name: info.name, nameNormalized: info.normalized)
        insert(project)
        return project
    }

    @MainActor
    func upsertEmotion(name: String) -> Emotion? {
        guard let info = EpisodePersistence.normalizeName(name) else { return nil }
        let normalized = info.normalized
        let descriptor = FetchDescriptor<Emotion>()
        if let existing = (try? fetch(descriptor))?.first(where: { $0.nameNormalized == normalized }) {
            existing.name = info.name
            existing.nameNormalized = info.normalized
            if existing.isSoftDeleted {
                existing.isSoftDeleted = false
                existing.deletedAt = nil
            }
            existing.updatedAt = Date()
            return existing
        }
        let emotion = Emotion(name: info.name, nameNormalized: info.normalized)
        insert(emotion)
        return emotion
    }

    @MainActor
    func upsertPlace(name: String) -> Place? {
        guard let info = EpisodePersistence.normalizeName(name) else { return nil }
        let normalized = info.normalized
        let descriptor = FetchDescriptor<Place>()
        if let existing = (try? fetch(descriptor))?.first(where: { $0.nameNormalized == normalized }) {
            existing.name = info.name
            existing.nameNormalized = info.normalized
            if existing.isSoftDeleted {
                existing.isSoftDeleted = false
                existing.deletedAt = nil
            }
            existing.updatedAt = Date()
            return existing
        }
        let place = Place(name: info.name, nameNormalized: info.normalized)
        insert(place)
        return place
    }

    @MainActor
    func upsertTags(from names: [String]) -> [Tag] {
        var result: [Tag] = []
        var seen = Set<String>()
        for name in names {
            guard let info = EpisodePersistence.normalizeTagName(name) else { continue }
            guard !seen.contains(info.normalized) else { continue }
            seen.insert(info.normalized)
            if let tag = upsertTag(name: info.name) {
                result.append(tag)
            }
        }
        return result
    }

    @MainActor
    func upsertPersons(from names: [String]) -> [Person] {
        var result: [Person] = []
        var seen = Set<String>()
        for name in names {
            guard let info = EpisodePersistence.normalizeName(name) else { continue }
            guard !seen.contains(info.normalized) else { continue }
            seen.insert(info.normalized)
            if let person = upsertPerson(name: info.name) {
                result.append(person)
            }
        }
        return result
    }

    @MainActor
    func upsertProjects(from names: [String]) -> [Project] {
        var result: [Project] = []
        var seen = Set<String>()
        for name in names {
            guard let info = EpisodePersistence.normalizeName(name) else { continue }
            guard !seen.contains(info.normalized) else { continue }
            seen.insert(info.normalized)
            if let project = upsertProject(name: info.name) {
                result.append(project)
            }
        }
        return result
    }

    @MainActor
    func upsertEmotions(from names: [String]) -> [Emotion] {
        var result: [Emotion] = []
        var seen = Set<String>()
        for name in names {
            guard let info = EpisodePersistence.normalizeName(name) else { continue }
            guard !seen.contains(info.normalized) else { continue }
            seen.insert(info.normalized)
            if let emotion = upsertEmotion(name: info.name) {
                result.append(emotion)
            }
        }
        return result
    }

    @MainActor
    func upsertPlaces(from names: [String]) -> [Place] {
        var result: [Place] = []
        var seen = Set<String>()
        for name in names {
            guard let info = EpisodePersistence.normalizeName(name) else { continue }
            guard !seen.contains(info.normalized) else { continue }
            seen.insert(info.normalized)
            if let place = upsertPlace(name: info.name) {
                result.append(place)
            }
        }
        return result
    }

    @MainActor
    func createEpisode(
        title: String,
        body: String?,
        date: Date,
        unlockDate: Date?,
        type: String?,
        tags: [String],
        persons: [String],
        projects: [String],
        emotions: [String],
        place: String?
    ) -> Episode {
        let now = Date()
        let episode = Episode(
            date: date,
            title: title,
            body: body,
            unlockDate: unlockDate,
            type: type,
            createdAt: now,
            updatedAt: now
        )
        episode.tags = upsertTags(from: tags)
        episode.persons = upsertPersons(from: persons)
        episode.projects = upsertProjects(from: projects)
        episode.emotions = upsertEmotions(from: emotions)
        if let place {
            episode.places = upsertPlaces(from: [place])
        } else {
            episode.places = []
        }
        insert(episode)
        saveWithDiagnostics(operation: "createEpisode")
        return episode
    }

    @MainActor
    func updateEpisode(
        _ episode: Episode,
        title: String,
        body: String?,
        date: Date,
        unlockDate: Date?,
        type: String?,
        tags: [String],
        persons: [String],
        projects: [String],
        emotions: [String],
        place: String?
    ) {
        episode.title = title
        episode.body = body
        episode.date = date
        episode.unlockDate = unlockDate
        episode.type = type
        episode.tags = upsertTags(from: tags)
        episode.persons = upsertPersons(from: persons)
        episode.projects = upsertProjects(from: projects)
        episode.emotions = upsertEmotions(from: emotions)
        if let place {
            episode.places = upsertPlaces(from: [place])
        } else {
            episode.places = []
        }
        episode.updatedAt = Date()
        saveWithDiagnostics(operation: "updateEpisode")
    }

    @MainActor
    func softDeleteEpisode(_ episode: Episode) {
        let now = Date()
        episode.isSoftDeleted = true
        episode.deletedAt = now
        episode.updatedAt = now

        // Fetch all logs and filter in Swift to avoid predicate macro limitations on nested key paths.
        let logDescriptor = FetchDescriptor<UnlockLog>()
        let logs = ((try? fetch(logDescriptor)) ?? []).filter { $0.episode.id == episode.id }
        for log in logs {
            log.isSoftDeleted = true
            log.deletedAt = now
            log.updatedAt = now
        }
        saveWithDiagnostics(operation: "softDeleteEpisode")
    }

    @MainActor
    func createUnlockLog(
        episode: Episode,
        talkedAt: Date,
        mediaPublicAt: Date?,
        projectNameText: String?,
        reaction: String,
        memo: String
    ) -> UnlockLog {
        let now = Date()
        let log = UnlockLog(
            talkedAt: talkedAt,
            mediaPublicAt: mediaPublicAt,
            projectNameText: projectNameText,
            reaction: reaction,
            memo: memo,
            episode: episode,
            createdAt: now,
            updatedAt: now
        )
        insert(log)
        if !episode.unlockLogs.contains(where: { $0.id == log.id }) {
            episode.unlockLogs.append(log)
        }
        saveWithDiagnostics(operation: "createUnlockLog")
        return log
    }

    @MainActor
    func updateUnlockLog(
        _ log: UnlockLog,
        talkedAt: Date,
        mediaPublicAt: Date?,
        projectNameText: String?,
        reaction: String,
        memo: String
    ) {
        log.talkedAt = talkedAt
        log.mediaPublicAt = mediaPublicAt
        log.projectNameText = projectNameText
        log.reaction = reaction
        log.memo = memo
        log.updatedAt = Date()
        saveWithDiagnostics(operation: "updateUnlockLog")
    }

    @MainActor
    func softDeleteUnlockLog(_ log: UnlockLog) {
        let now = Date()
        log.isSoftDeleted = true
        log.deletedAt = now
        log.updatedAt = now
        saveWithDiagnostics(operation: "softDeleteUnlockLog")
    }

    @MainActor
    func softDeleteTag(_ tag: Tag) -> [UUID] {
        let descriptor = FetchDescriptor<Episode>()
        let episodes = (try? fetch(descriptor)) ?? []
        let linkedActiveEpisodes = episodes.filter { episode in
            guard !episode.isSoftDeleted else { return false }
            return episode.tags.contains { $0.id == tag.id }
        }

        let episodeIds = linkedActiveEpisodes.map { $0.id }
        for episode in linkedActiveEpisodes {
            episode.tags.removeAll { $0.id == tag.id }
            episode.updatedAt = Date()
        }
        tag.isSoftDeleted = true
        tag.deletedAt = Date()
        tag.updatedAt = Date()
        saveWithDiagnostics(operation: "softDeleteTag")
        return episodeIds
    }

    @MainActor
    func restoreTag(_ tag: Tag, episodeIds: [UUID]) {
        tag.isSoftDeleted = false
        tag.deletedAt = nil
        tag.updatedAt = Date()
        for id in episodeIds {
            let descriptor = FetchDescriptor<Episode>(predicate: #Predicate { $0.id == id })
            guard let episode = (try? fetch(descriptor))?.first else { continue }
            guard !episode.isSoftDeleted else { continue }
            if !episode.tags.contains(where: { $0.id == tag.id }) {
                episode.tags.append(tag)
                episode.updatedAt = Date()
            }
        }
        saveWithDiagnostics(operation: "restoreTag")
    }
}
