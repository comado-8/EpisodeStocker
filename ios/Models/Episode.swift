import Foundation
import SwiftData

@Model
final class Episode {
    var id: UUID = UUID()
    var date: Date = Date()
    var title: String = ""
    var body: String?
    var unlockDate: Date?
    var type: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isSoftDeleted: Bool = false
    var deletedAt: Date?

    @Relationship(deleteRule: .nullify)
    var tags: [Tag] = []
    @Relationship(deleteRule: .nullify)
    var persons: [Person] = []
    @Relationship(deleteRule: .nullify)
    var projects: [Project] = []
    @Relationship(deleteRule: .nullify)
    var emotions: [Emotion] = []
    @Relationship(deleteRule: .nullify)
    var places: [Place] = []

    @Relationship(deleteRule: .nullify)
    var unlockLogs: [UnlockLog] = []

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        title: String = "",
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
    var id: UUID = UUID()
    var talkedAt: Date = Date()
    var mediaPublicAt: Date?
    var mediaType: String?
    var projectNameText: String?
    var reaction: String = ""
    var memo: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isSoftDeleted: Bool = false
    var deletedAt: Date?

    @Relationship(deleteRule: .nullify, inverse: \Episode.unlockLogs)
    var episode: Episode?

    init(
        id: UUID = UUID(),
        talkedAt: Date,
        mediaPublicAt: Date? = nil,
        mediaType: String? = nil,
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
        self.mediaType = mediaType
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
    var id: UUID = UUID()
    var name: String = ""
    var nameNormalized: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isSoftDeleted: Bool = false
    var deletedAt: Date?
    @Relationship(deleteRule: .nullify, inverse: \Episode.tags)
    var episodes: [Episode] = []

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
    var id: UUID = UUID()
    var name: String = ""
    var nameNormalized: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isSoftDeleted: Bool = false
    var deletedAt: Date?
    @Relationship(deleteRule: .nullify, inverse: \Episode.persons)
    var episodes: [Episode] = []

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
final class Project {
    var id: UUID = UUID()
    var name: String = ""
    var nameNormalized: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isSoftDeleted: Bool = false
    var deletedAt: Date?
    @Relationship(deleteRule: .nullify, inverse: \Episode.projects)
    var episodes: [Episode] = []

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
final class Emotion {
    var id: UUID = UUID()
    var name: String = ""
    var nameNormalized: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isSoftDeleted: Bool = false
    var deletedAt: Date?
    @Relationship(deleteRule: .nullify, inverse: \Episode.emotions)
    var episodes: [Episode] = []

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
final class Place {
    var id: UUID = UUID()
    var name: String = ""
    var nameNormalized: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isSoftDeleted: Bool = false
    var deletedAt: Date?
    @Relationship(deleteRule: .nullify, inverse: \Episode.places)
    var episodes: [Episode] = []

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

enum ReleaseLogOutcome: String, Codable, CaseIterable, Identifiable {
    case hit = "ウケた"
    case soSo = "イマイチ"
    case shelved = "お蔵"

    var id: String { rawValue }

    var label: String { rawValue }
}

enum ReleaseLogMediaPreset: String, CaseIterable, Identifiable {
    case tv = "テレビ"
    case streaming = "配信"
    case radio = "ラジオ"
    case magazine = "雑誌"
    case event = "イベント"
    case sns = "SNS"
    case other = "その他"

    var id: String { rawValue }
}

extension Episode {
    var activeUnlockLogs: [UnlockLog] {
        unlockLogs.filter { !$0.isSoftDeleted }
    }

    var talkedCount: Int {
        activeUnlockLogs.count
    }

    var latestTalkedAt: Date? {
        activeUnlockLogs.map(\.talkedAt).max()
    }

    func reactionCount(_ outcome: ReleaseLogOutcome) -> Int {
        activeUnlockLogs.filter { $0.reaction == outcome.rawValue }.count
    }
}

struct SubscriptionStatus: Codable, Equatable {
    var plan: Plan
    var expiryDate: Date?
    var trialEndDate: Date?
    var nextPlan: Plan? = nil
    var nextPlanEffectiveDate: Date? = nil
    var willAutoRenew: Bool? = nil

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
