import Foundation

enum PremiumFeature {
    case analyticsTab
    case advancedSort
    case advancedSearch
    case export
    case backup
    case episodeQuotaOver50
}

enum PaywallTrigger: String, Identifiable {
    case analyticsTab
    case advancedSort
    case advancedSearch
    case export
    case backup
    case episodeQuotaOver50

    var id: String { rawValue }

    var title: String {
        switch self {
        case .analyticsTab:
            return "分析タブは有料機能です"
        case .advancedSort:
            return "この並び替えは有料機能です"
        case .advancedSearch:
            return "詳細検索の条件設定は有料機能です"
        case .export:
            return "エクスポートは有料機能です"
        case .backup:
            return "クラウド同期は有料機能です"
        case .episodeQuotaOver50:
            return "無料プランは50件までです"
        }
    }

    var message: String {
        switch self {
        case .analyticsTab:
            return "分析ダッシュボードを利用するにはサブスクリプション登録が必要です。"
        case .advancedSort:
            return "最近話した順や話した回数順はサブスクリプションで利用できます。"
        case .advancedSearch:
            return "詳細検索シート内の条件検索（回数/日付/媒体/リアクション）を使うにはサブスクリプション登録が必要です。"
        case .export:
            return "PDF/txtエクスポートはサブスクリプションで利用できます。"
        case .backup:
            return "クラウド同期機能はサブスクリプションで利用できます。"
        case .episodeQuotaOver50:
            return "51件目を登録するにはサブスクリプション登録が必要です。"
        }
    }

    var feature: PremiumFeature {
        switch self {
        case .analyticsTab:
            return .analyticsTab
        case .advancedSort:
            return .advancedSort
        case .advancedSearch:
            return .advancedSearch
        case .export:
            return .export
        case .backup:
            return .backup
        case .episodeQuotaOver50:
            return .episodeQuotaOver50
        }
    }
}

@MainActor
final class PremiumAccessViewModel: ObservableObject {
    static let freeEpisodeLimit = 50
    private static let secondsPerDay: TimeInterval = 86_400

    @Published private(set) var subscriptionStatus = SubscriptionStatus(plan: .free, expiryDate: nil, trialEndDate: nil)
    @Published private(set) var hasLoadedStatus = false
    @Published private(set) var lastErrorMessage: String?

    private let service: SubscriptionService
    private let now: () -> Date
    private let cloudSyncPreferenceRepository: CloudSyncPreferenceRepository
    private let entitlementCache: SubscriptionEntitlementCaching
    private var isLoadingStatus = false

    init(
        service: SubscriptionService = SubscriptionServiceFactory.makeService(),
        cloudSyncPreferenceRepository: CloudSyncPreferenceRepository = UserDefaultsCloudSyncPreferenceRepository(),
        entitlementCache: SubscriptionEntitlementCaching = UserDefaultsSubscriptionEntitlementCache(),
        now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.cloudSyncPreferenceRepository = cloudSyncPreferenceRepository
        self.entitlementCache = entitlementCache
        self.now = now
    }

    var trialRemainingDays: Int {
        guard let trialEndDate = subscriptionStatus.trialEndDate else { return 0 }
        let seconds = trialEndDate.timeIntervalSince(now())
        guard seconds > 0 else { return 0 }
        return Int(ceil(seconds / Self.secondsPerDay))
    }

    var hasPremiumAccess: Bool {
        subscriptionStatus.plan != .free || trialRemainingDays > 0
    }

    func refresh() async {
        guard !isLoadingStatus else { return }
        isLoadingStatus = true
        defer { isLoadingStatus = false }

        do {
            let status = try await service.fetchStatus()
            subscriptionStatus = status
            let hasPremium = Self.hasPremiumAccess(status: status, now: now)
            entitlementCache.setPremiumAccessCachedState(hasPremium ? .granted : .denied)
            if !hasPremium, cloudSyncPreferenceRepository.isCloudSyncRequested() {
                cloudSyncPreferenceRepository.setCloudSyncRequested(false)
            }
            hasLoadedStatus = true
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func ensureStatusLoaded() async {
        guard !hasLoadedStatus, !isLoadingStatus else { return }
        await refresh()
    }

    func hasAccess(to _: PremiumFeature) -> Bool {
        hasPremiumAccess
    }

    func canCreateEpisode(currentActiveCount: Int) -> Bool {
        guard !hasAccess(to: .episodeQuotaOver50) else { return true }
        return currentActiveCount < Self.freeEpisodeLimit
    }

    private static func hasPremiumAccess(status: SubscriptionStatus, now: () -> Date) -> Bool {
        if status.plan != .free {
            return true
        }
        guard let trialEndDate = status.trialEndDate else { return false }
        return trialEndDate > now()
    }
}
