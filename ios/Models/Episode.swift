import Foundation
import SwiftData

@Model
final class Episode {
    @Attribute(.unique) var id: UUID
    var date: Date
    var title: String
    var body: String?
    var unlockDate: Date?
    var type: String?
    var createdAt: Date
    var updatedAt: Date
    var isSoftDeleted: Bool
    var deletedAt: Date?

    @Relationship(deleteRule: .nullify)
    var tags: [Tag]
    @Relationship(deleteRule: .nullify)
    var persons: [Person]
    @Relationship(deleteRule: .nullify)
    var projects: [Project]
    @Relationship(deleteRule: .nullify)
    var emotions: [Emotion]
    @Relationship(deleteRule: .nullify)
    var places: [Place]

    @Relationship(deleteRule: .nullify)
    var unlockLogs: [UnlockLog]

    init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        body: String? = nil,
        unlockDate: Date? = nil,
        type: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSoftDeleted: Bool = false,
        deletedAt: Date? = nil,
        tags: [Tag] = [],
        persons: [Person] = [],
        projects: [Project] = [],
        emotions: [Emotion] = [],
        places: [Place] = [],
        unlockLogs: [UnlockLog] = []
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.body = body
        self.unlockDate = unlockDate
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSoftDeleted = isSoftDeleted
        self.deletedAt = deletedAt
        self.tags = tags
        self.persons = persons
        self.projects = projects
        self.emotions = emotions
        self.places = places
        self.unlockLogs = unlockLogs
    }

    var isUnlocked: Bool {
        guard let unlockDate else { return false }
        return unlockDate <= Date()
    }
}

@Model
final class UnlockLog {
    @Attribute(.unique) var id: UUID
    var talkedAt: Date
    var mediaPublicAt: Date?
    var projectNameText: String?
    var reaction: String
    var memo: String
    var createdAt: Date
    var updatedAt: Date
    var isSoftDeleted: Bool
    var deletedAt: Date?

    var episode: Episode

    init(
        id: UUID = UUID(),
        talkedAt: Date,
        mediaPublicAt: Date? = nil,
        projectNameText: String? = nil,
        reaction: String,
        memo: String,
        episode: Episode,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSoftDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.talkedAt = talkedAt
        self.mediaPublicAt = mediaPublicAt
        self.projectNameText = projectNameText
        self.reaction = reaction
        self.memo = memo
        self.episode = episode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSoftDeleted = isSoftDeleted
        self.deletedAt = deletedAt
    }
}

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var name: String
    var nameNormalized: String
    var createdAt: Date
    var updatedAt: Date
    var isSoftDeleted: Bool
    var deletedAt: Date?
    @Relationship(inverse: \Episode.tags)
    var episodes: [Episode]

    init(
        id: UUID = UUID(),
        name: String,
        nameNormalized: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSoftDeleted: Bool = false,
        deletedAt: Date? = nil,
        episodes: [Episode] = []
    ) {
        self.id = id
        self.name = name
        self.nameNormalized = nameNormalized
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSoftDeleted = isSoftDeleted
        self.deletedAt = deletedAt
        self.episodes = episodes
    }
}

@Model
final class Person {
    @Attribute(.unique) var id: UUID
    var name: String
    var nameNormalized: String
    var createdAt: Date
    var updatedAt: Date
    var isSoftDeleted: Bool
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        nameNormalized: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSoftDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.nameNormalized = nameNormalized
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSoftDeleted = isSoftDeleted
        self.deletedAt = deletedAt
    }
}

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var nameNormalized: String
    var createdAt: Date
    var updatedAt: Date
    var isSoftDeleted: Bool
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        nameNormalized: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSoftDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.nameNormalized = nameNormalized
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSoftDeleted = isSoftDeleted
        self.deletedAt = deletedAt
    }
}

@Model
final class Emotion {
    @Attribute(.unique) var id: UUID
    var name: String
    var nameNormalized: String
    var createdAt: Date
    var updatedAt: Date
    var isSoftDeleted: Bool
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        nameNormalized: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSoftDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.nameNormalized = nameNormalized
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSoftDeleted = isSoftDeleted
        self.deletedAt = deletedAt
    }
}

@Model
final class Place {
    @Attribute(.unique) var id: UUID
    var name: String
    var nameNormalized: String
    var createdAt: Date
    var updatedAt: Date
    var isSoftDeleted: Bool
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        nameNormalized: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSoftDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.nameNormalized = nameNormalized
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSoftDeleted = isSoftDeleted
        self.deletedAt = deletedAt
    }
}

enum ReleaseLogOutcome: String, Codable, CaseIterable, Identifiable {
    case hit = "ウケた"
    case soSo = "イマイチ"
    case shelved = "お蔵"

    var id: String { rawValue }

    var label: String { rawValue }
}

struct SubscriptionStatus: Codable, Equatable {
    var plan: Plan
    var expiryDate: Date?
    var trialEndDate: Date?

    enum Plan: String, Codable, CaseIterable {
        case free
        case monthly
        case yearly
    }
}

struct SettingItem: Identifiable, Codable {
    var id = UUID()
    var key: String
    var value: String
}
