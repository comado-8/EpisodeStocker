import Foundation

protocol CloudSyncPreferenceRepository {
    func isCloudSyncRequested() -> Bool
    func setCloudSyncRequested(_ requested: Bool)
    func lastSyncAt() -> Date?
    func setLastSyncAt(_ date: Date?)
}

final class UserDefaultsCloudSyncPreferenceRepository: CloudSyncPreferenceRepository {
    private let settingsRepository: SettingsRepository

    init(settingsRepository: SettingsRepository = UserDefaultsSettingsRepository()) {
        self.settingsRepository = settingsRepository
    }

    func isCloudSyncRequested() -> Bool {
        settingsRepository.bool(for: .cloudSyncRequested)
            || settingsRepository.bool(for: .cloudBackupEnabled)
    }

    func setCloudSyncRequested(_ requested: Bool) {
        settingsRepository.set(requested, for: .cloudSyncRequested)
        // Keep legacy key in sync for backward compatibility.
        settingsRepository.set(requested, for: .cloudBackupEnabled)
    }

    func lastSyncAt() -> Date? {
        settingsRepository.date(for: .cloudSyncLastSuccessAt)
            ?? settingsRepository.date(for: .cloudBackupLastRunAt)
    }

    func setLastSyncAt(_ date: Date?) {
        settingsRepository.set(date, for: .cloudSyncLastSuccessAt)
        // Keep legacy key in sync for backward compatibility.
        settingsRepository.set(date, for: .cloudBackupLastRunAt)
    }
}

protocol SubscriptionEntitlementCaching {
    func premiumAccessCachedState() -> PremiumAccessCachedState
    func setPremiumAccessCachedState(_ value: PremiumAccessCachedState)
}

enum PremiumAccessCachedState: Equatable {
    case unknown
    case denied
    case granted

    init(cachedValue: Bool?) {
        switch cachedValue {
        case .some(true):
            self = .granted
        case .some(false):
            self = .denied
        case .none:
            self = .unknown
        }
    }

    var cachedValue: Bool? {
        switch self {
        case .unknown:
            return nil
        case .denied:
            return false
        case .granted:
            return true
        }
    }
}

final class UserDefaultsSubscriptionEntitlementCache: SubscriptionEntitlementCaching {
    private let settingsRepository: SettingsRepository

    init(settingsRepository: SettingsRepository = UserDefaultsSettingsRepository()) {
        self.settingsRepository = settingsRepository
    }

    func premiumAccessCachedState() -> PremiumAccessCachedState {
        PremiumAccessCachedState(cachedValue: settingsRepository.optionalBool(for: .hasPremiumAccessCached))
    }

    func setPremiumAccessCachedState(_ value: PremiumAccessCachedState) {
        settingsRepository.setOptionalBool(value.cachedValue, for: .hasPremiumAccessCached)
    }
}

protocol CloudSyncModeResolving {
    func resolveEffectiveCloudSyncMode() -> CloudSyncMode
    func resolveEffectiveCloudSyncEnabled() -> Bool
}

extension CloudSyncModeResolving {
    func resolveEffectiveCloudSyncEnabled() -> Bool {
        resolveEffectiveCloudSyncMode().allowsSync
    }
}

enum CloudSyncMode: Equatable {
    case disabled
    case enabled
    case denied
    case unknown

    var allowsSync: Bool {
        self == .enabled
    }
}

struct DefaultCloudSyncModeResolver: CloudSyncModeResolving {
    private let preferenceRepository: CloudSyncPreferenceRepository
    private let entitlementCache: SubscriptionEntitlementCaching

    init(
        preferenceRepository: CloudSyncPreferenceRepository = UserDefaultsCloudSyncPreferenceRepository(),
        entitlementCache: SubscriptionEntitlementCaching = UserDefaultsSubscriptionEntitlementCache()
    ) {
        self.preferenceRepository = preferenceRepository
        self.entitlementCache = entitlementCache
    }

    func resolveEffectiveCloudSyncMode() -> CloudSyncMode {
        guard preferenceRepository.isCloudSyncRequested() else { return .disabled }
        switch entitlementCache.premiumAccessCachedState() {
        case .granted:
            return .enabled
        case .denied:
            return .denied
        case .unknown:
            return .unknown
        }
    }
}
