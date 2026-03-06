import Foundation

struct AnalyticsTalkLogInput: Sendable, Equatable {
    let talkedAt: Date
    let reaction: String
}

struct AnalyticsEpisodeInput: Sendable, Equatable {
    let episodeID: UUID
    let title: String
    let tags: [String]
    let logs: [AnalyticsTalkLogInput]
}

struct DigUpSuggestionItem: Identifiable, Sendable, Equatable {
    let episodeID: UUID
    let title: String
    let lastTalkedAt: Date
    let hitRate: Double
    let talkCount: Int
    let score: Double

    var id: UUID { episodeID }
}

struct EpisodeTopItem: Identifiable, Sendable, Equatable {
    let episodeID: UUID
    let title: String
    let talkCount: Int
    let lastTalkedAt: Date?

    var id: UUID { episodeID }
}

struct EpisodeDormantItem: Identifiable, Sendable, Equatable {
    let episodeID: UUID
    let title: String
    let lastTalkedAt: Date?
    let talkCount: Int

    var id: UUID { episodeID }
}

struct EpisodeHitRateItem: Identifiable, Sendable, Equatable {
    let episodeID: UUID
    let title: String
    let hitRate: Double
    let talkCount: Int
    let lastTalkedAt: Date?

    var id: UUID { episodeID }
}

struct EpisodeOverusedItem: Identifiable, Sendable, Equatable {
    let episodeID: UUID
    let title: String
    let recent30DayTalkCount: Int
    let lastTalkedAt: Date?

    var id: UUID { episodeID }
}

struct TagTalkCountItem: Identifiable, Sendable, Equatable {
    let tagName: String
    let talkCount: Int

    var id: String { tagName }
}

struct TagHitRateItem: Identifiable, Sendable, Equatable {
    let tagName: String
    let hitRate: Double
    let talkCount: Int

    var id: String { tagName }
}

struct AnalyticsSnapshot: Sendable, Equatable {
    let monthlyTalkCount: Int
    let digUpSuggestions: [DigUpSuggestionItem]
    let topTalkedEpisodes: [EpisodeTopItem]
    let dormantEpisodes: [EpisodeDormantItem]
    let strongEpisodes: [EpisodeHitRateItem]
    let overusedEpisodes: [EpisodeOverusedItem]
    let tagTalkCounts: [TagTalkCountItem]
    let tagHitRates: [TagHitRateItem]
}

enum AnalyticsSnapshotBuilder {
    static let minimumTalkCountForRate = 3
    static let suggestionLimit = 5
    static let rankingLimit = 5

    private struct EpisodeStats {
        let episodeID: UUID
        let title: String
        let talkCount: Int
        let hitCount: Int
        let lastTalkedAt: Date?
        let recent30DayTalkCount: Int

        var hitRate: Double {
            guard talkCount > 0 else { return 0 }
            return Double(hitCount) / Double(talkCount)
        }
    }

    static func build(
        episodes: [AnalyticsEpisodeInput],
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> AnalyticsSnapshot {
        guard !Task.isCancelled else { return emptySnapshot() }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let currentMonth = calendar.dateComponents([.year, .month], from: now)
        let todayStart = calendar.startOfDay(for: now)
        let recentWindowStart = calendar.date(byAdding: .day, value: -30, to: todayStart) ?? todayStart

        var monthTalkCount = 0
        var stats: [EpisodeStats] = []
        var tagTalkCounts: [String: Int] = [:]
        var tagHitCounts: [String: Int] = [:]

        for episode in episodes {
            guard !Task.isCancelled else { return emptySnapshot() }

            let talkCount = episode.logs.count
            var hitCount = 0
            var recent30DayTalkCount = 0
            var lastTalkedAt: Date?

            for log in episode.logs {
                guard !Task.isCancelled else { return emptySnapshot() }

                let logMonth = calendar.dateComponents([.year, .month], from: log.talkedAt)
                if logMonth.year == currentMonth.year, logMonth.month == currentMonth.month {
                    monthTalkCount += 1
                }

                if log.reaction == ReleaseLogOutcome.hit.rawValue {
                    hitCount += 1
                }

                if log.talkedAt >= recentWindowStart, log.talkedAt <= now {
                    recent30DayTalkCount += 1
                }

                if let currentLast = lastTalkedAt {
                    if log.talkedAt > currentLast {
                        lastTalkedAt = log.talkedAt
                    }
                } else {
                    lastTalkedAt = log.talkedAt
                }
            }

            let uniqueTags = Array(Set(episode.tags.filter { !$0.isEmpty }))
            for log in episode.logs {
                guard !Task.isCancelled else { return emptySnapshot() }
                for tag in uniqueTags {
                    tagTalkCounts[tag, default: 0] += 1
                    if log.reaction == ReleaseLogOutcome.hit.rawValue {
                        tagHitCounts[tag, default: 0] += 1
                    }
                }
            }

            stats.append(
                EpisodeStats(
                    episodeID: episode.episodeID,
                    title: episode.title,
                    talkCount: talkCount,
                    hitCount: hitCount,
                    lastTalkedAt: lastTalkedAt,
                    recent30DayTalkCount: recent30DayTalkCount
                )
            )
        }

        guard !Task.isCancelled else { return emptySnapshot() }

        let topTalkedEpisodes = stats
            .sorted { lhs, rhs in
                if lhs.talkCount != rhs.talkCount {
                    return lhs.talkCount > rhs.talkCount
                }
                let lhsLast = lhs.lastTalkedAt ?? .distantPast
                let rhsLast = rhs.lastTalkedAt ?? .distantPast
                if lhsLast != rhsLast {
                    return lhsLast > rhsLast
                }
                return lhs.title < rhs.title
            }
            .prefix(rankingLimit)
            .map {
                EpisodeTopItem(
                    episodeID: $0.episodeID,
                    title: $0.title,
                    talkCount: $0.talkCount,
                    lastTalkedAt: $0.lastTalkedAt
                )
            }

        guard !Task.isCancelled else { return emptySnapshot() }

        let dormantEpisodes = stats
            .sorted { lhs, rhs in
                let lhsNeverTalked = lhs.lastTalkedAt == nil
                let rhsNeverTalked = rhs.lastTalkedAt == nil
                if lhsNeverTalked != rhsNeverTalked {
                    return lhsNeverTalked && !rhsNeverTalked
                }
                let lhsLast = lhs.lastTalkedAt ?? .distantFuture
                let rhsLast = rhs.lastTalkedAt ?? .distantFuture
                if lhsLast != rhsLast {
                    return lhsLast < rhsLast
                }
                if lhs.talkCount != rhs.talkCount {
                    return lhs.talkCount < rhs.talkCount
                }
                return lhs.title < rhs.title
            }
            .prefix(rankingLimit)
            .map {
                EpisodeDormantItem(
                    episodeID: $0.episodeID,
                    title: $0.title,
                    lastTalkedAt: $0.lastTalkedAt,
                    talkCount: $0.talkCount
                )
            }

        guard !Task.isCancelled else { return emptySnapshot() }

        let strongEpisodes = stats
            .filter { $0.talkCount >= minimumTalkCountForRate }
            .sorted { lhs, rhs in
                if lhs.hitRate != rhs.hitRate {
                    return lhs.hitRate > rhs.hitRate
                }
                if lhs.talkCount != rhs.talkCount {
                    return lhs.talkCount > rhs.talkCount
                }
                let lhsLast = lhs.lastTalkedAt ?? .distantPast
                let rhsLast = rhs.lastTalkedAt ?? .distantPast
                if lhsLast != rhsLast {
                    return lhsLast > rhsLast
                }
                return lhs.title < rhs.title
            }
            .prefix(rankingLimit)
            .map {
                EpisodeHitRateItem(
                    episodeID: $0.episodeID,
                    title: $0.title,
                    hitRate: $0.hitRate,
                    talkCount: $0.talkCount,
                    lastTalkedAt: $0.lastTalkedAt
                )
            }

        guard !Task.isCancelled else { return emptySnapshot() }

        let overusedEpisodes = stats
            .filter { $0.recent30DayTalkCount > 0 }
            .sorted { lhs, rhs in
                if lhs.recent30DayTalkCount != rhs.recent30DayTalkCount {
                    return lhs.recent30DayTalkCount > rhs.recent30DayTalkCount
                }
                let lhsLast = lhs.lastTalkedAt ?? .distantPast
                let rhsLast = rhs.lastTalkedAt ?? .distantPast
                if lhsLast != rhsLast {
                    return lhsLast > rhsLast
                }
                return lhs.title < rhs.title
            }
            .prefix(rankingLimit)
            .map {
                EpisodeOverusedItem(
                    episodeID: $0.episodeID,
                    title: $0.title,
                    recent30DayTalkCount: $0.recent30DayTalkCount,
                    lastTalkedAt: $0.lastTalkedAt
                )
            }

        guard !Task.isCancelled else { return emptySnapshot() }

        let digUpSuggestions = stats
            .compactMap { stat -> DigUpSuggestionItem? in
                guard stat.talkCount >= minimumTalkCountForRate, let lastTalkedAt = stat.lastTalkedAt else {
                    return nil
                }
                let lastTalkedAtStart = calendar.startOfDay(for: lastTalkedAt)
                let rawDays = calendar.dateComponents([.day], from: lastTalkedAtStart, to: todayStart).day ?? 0
                let unusedDays = max(0, rawDays)
                let score = stat.hitRate * Double(unusedDays)
                return DigUpSuggestionItem(
                    episodeID: stat.episodeID,
                    title: stat.title,
                    lastTalkedAt: lastTalkedAt,
                    hitRate: stat.hitRate,
                    talkCount: stat.talkCount,
                    score: score
                )
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                if lhs.hitRate != rhs.hitRate {
                    return lhs.hitRate > rhs.hitRate
                }
                if lhs.talkCount != rhs.talkCount {
                    return lhs.talkCount > rhs.talkCount
                }
                return lhs.title < rhs.title
            }
            .prefix(suggestionLimit)

        let digUpSuggestionList = Array(digUpSuggestions)

        guard !Task.isCancelled else { return emptySnapshot() }

        let tagTalkRanking = tagTalkCounts
            .map { TagTalkCountItem(tagName: $0.key, talkCount: $0.value) }
            .sorted { lhs, rhs in
                if lhs.talkCount != rhs.talkCount {
                    return lhs.talkCount > rhs.talkCount
                }
                return lhs.tagName < rhs.tagName
            }
            .prefix(rankingLimit)

        let tagTalkRankingList = Array(tagTalkRanking)

        guard !Task.isCancelled else { return emptySnapshot() }

        let tagHitRateRanking = tagTalkCounts
            .compactMap { tagName, talkCount -> TagHitRateItem? in
                guard talkCount >= minimumTalkCountForRate else { return nil }
                let hitCount = tagHitCounts[tagName, default: 0]
                let hitRate = talkCount > 0 ? Double(hitCount) / Double(talkCount) : 0
                return TagHitRateItem(tagName: tagName, hitRate: hitRate, talkCount: talkCount)
            }
            .sorted { lhs, rhs in
                if lhs.hitRate != rhs.hitRate {
                    return lhs.hitRate > rhs.hitRate
                }
                if lhs.talkCount != rhs.talkCount {
                    return lhs.talkCount > rhs.talkCount
                }
                return lhs.tagName < rhs.tagName
            }
            .prefix(rankingLimit)

        let tagHitRateRankingList = Array(tagHitRateRanking)

        return AnalyticsSnapshot(
            monthlyTalkCount: monthTalkCount,
            digUpSuggestions: digUpSuggestionList,
            topTalkedEpisodes: topTalkedEpisodes,
            dormantEpisodes: dormantEpisodes,
            strongEpisodes: strongEpisodes,
            overusedEpisodes: overusedEpisodes,
            tagTalkCounts: tagTalkRankingList,
            tagHitRates: tagHitRateRankingList
        )
    }

    private static func emptySnapshot() -> AnalyticsSnapshot {
        AnalyticsSnapshot(
            monthlyTalkCount: 0,
            digUpSuggestions: [],
            topTalkedEpisodes: [],
            dormantEpisodes: [],
            strongEpisodes: [],
            overusedEpisodes: [],
            tagTalkCounts: [],
            tagHitRates: []
        )
    }
}
