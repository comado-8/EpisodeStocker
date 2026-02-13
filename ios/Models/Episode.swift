import Foundation

enum EpisodeStatus: String, Codable, CaseIterable, Identifiable {
    case unpublished
    case published
    var id: String { rawValue }
}

struct Tag: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var color: String?
    var usageCount: Int
}

struct EpisodeHistory: Identifiable, Codable, Hashable {
    let id: UUID
    var episodeId: UUID
    var eventName: String
    var happenedAt: Date
    var notes: String?
}

struct Episode: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var body: String?
    var tags: [UUID]
    var status: EpisodeStatus
    var category: String?
    var createdAt: Date
    var updatedAt: Date
    var histories: [EpisodeHistory]?
}

struct SubscriptionStatus: Codable {
    var plan: Plan
    var expiryDate: Date?
    var trialEndDate: Date?

    enum Plan: String, Codable, CaseIterable { case free, monthly, yearly }
}

struct SettingItem: Identifiable, Codable {
    let id = UUID()
    var key: String
    var value: String
}
