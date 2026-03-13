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
            return "分析ダッシュボードはPro機能です"
        case .advancedSort:
            return "この並び替えはPro機能です"
        case .advancedSearch:
            return "この詳細検索はPro機能です"
        case .export:
            return "エクスポートはPro機能です"
        case .backup:
            return "バックアップはPro機能です"
        case .episodeQuotaOver50:
            return "無料プランは50件までです"
        }
    }

    var message: String {
        switch self {
        case .analyticsTab:
            return "掘り起こし候補・傾向分析・タグ分析を使うには、Proプランへアップグレードしてください。"
        case .advancedSort:
            return "最近話した順・話した回数順などの履歴ベース並び替えは、Proプランで利用できます。"
        case .advancedSearch:
            return "回数・日付・媒体・リアクションを使った詳細検索は、Proプランで利用できます。"
        case .export:
            return "PDF/txt エクスポートを利用するには、Proプランへのアップグレードが必要です。"
        case .backup:
            return "iCloud同期と暗号化バックアップ機能は、Proプランで利用できます。"
        case .episodeQuotaOver50:
            return "51件目以降を登録するには、Proプランへのアップグレードが必要です。"
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

    func refresh(forceRefresh: Bool = false) async {
        guard !isLoadingStatus else { return }
        isLoadingStatus = true
        defer { isLoadingStatus = false }

        do {
            let status = try await service.fetchStatus(forceRefresh: forceRefresh)
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
        await refresh(forceRefresh: false)
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
