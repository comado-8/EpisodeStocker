import Combine
import Foundation

@MainActor
final class AnalyticsMVPViewModel: ObservableObject {
    @Published private(set) var snapshot: AnalyticsSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let nowProvider: () -> Date
    private let timeZone: TimeZone

    private var cachedSnapshot: AnalyticsSnapshot?
    private var cachedFingerprint: Int?
    private var refreshGeneration = 0
    private var snapshotTask: Task<AnalyticsSnapshot, Never>?

    init(
        nowProvider: @escaping () -> Date = Date.init,
        timeZone: TimeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
    ) {
        self.nowProvider = nowProvider
        self.timeZone = timeZone
    }

    func refresh(episodes: [Episode]) async {
        if let snapshotTask {
            snapshotTask.cancel()
            _ = await snapshotTask.value
            self.snapshotTask = nil
        }

        let inputs = Self.makeInputs(from: episodes)
        let now = nowProvider()
        let targetTimeZone = timeZone
        let fingerprint = Self.makeCombinedFingerprint(
            for: inputs,
            now: now,
            timeZone: targetTimeZone
        )
        refreshGeneration += 1
        let generation = refreshGeneration

        if cachedFingerprint == fingerprint, let cachedSnapshot {
            snapshot = cachedSnapshot
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        let task = Task(priority: .userInitiated) {
            AnalyticsSnapshotBuilder.build(
                episodes: inputs,
                now: now,
                timeZone: targetTimeZone
            )
        }
        snapshotTask = task
        let builtSnapshot = await task.value

        if generation == refreshGeneration {
            snapshotTask = nil
        }

        guard !Task.isCancelled else {
            if generation == refreshGeneration {
                isLoading = false
            }
            return
        }

        guard generation == refreshGeneration else {
            return
        }

        snapshot = builtSnapshot
        cachedSnapshot = builtSnapshot
        cachedFingerprint = fingerprint
        isLoading = false
    }

    deinit {
        snapshotTask?.cancel()
    }

    private static func makeInputs(from episodes: [Episode]) -> [AnalyticsEpisodeInput] {
        episodes.map { episode in
            let tags = episode.tags
                .filter { !$0.isSoftDeleted }
                .map { normalizedTagName($0.name) }
                .filter { !$0.isEmpty }

            let logs = episode.activeUnlockLogs.map {
                AnalyticsTalkLogInput(talkedAt: $0.talkedAt, reaction: $0.reaction)
            }

            return AnalyticsEpisodeInput(
                episodeID: episode.id,
                title: episode.title,
                tags: tags,
                logs: logs
            )
        }
    }

    private static func makeFingerprint(for episodes: [AnalyticsEpisodeInput]) -> Int {
        var hasher = Hasher()

        for episode in episodes.sorted(by: { $0.episodeID.uuidString < $1.episodeID.uuidString }) {
            hasher.combine(episode.episodeID)
            hasher.combine(episode.title)

            for tag in episode.tags.sorted() {
                hasher.combine(tag)
            }

            for log in episode.logs.sorted(by: { lhs, rhs in
                if lhs.talkedAt != rhs.talkedAt {
                    return lhs.talkedAt < rhs.talkedAt
                }
                return lhs.reaction < rhs.reaction
            }) {
                hasher.combine(log.talkedAt.timeIntervalSince1970)
                hasher.combine(log.reaction)
            }
        }

        return hasher.finalize()
    }

    private static func makeCombinedFingerprint(
        for episodes: [AnalyticsEpisodeInput],
        now: Date,
        timeZone: TimeZone
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(makeFingerprint(for: episodes))
        hasher.combine(timeZone.identifier)
        hasher.combine(Int(now.timeIntervalSince1970 / 3_600))
        return hasher.finalize()
    }

    private static func normalizedTagName(_ raw: String) -> String {
        EpisodePersistence.stripLeadingTagPrefix(raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
