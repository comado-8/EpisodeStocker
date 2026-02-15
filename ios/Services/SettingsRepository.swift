import Foundation

enum SettingsKey: String {
    case cloudBackupEnabled
    case cloudBackupLastRunAt
}

/// Persistence boundary for settings values used by backup and subscription-related flows.
/// This interface owns read/write responsibility for boolean flags and date timestamps.
protocol SettingsRepository {
    func bool(for key: SettingsKey) -> Bool
    func set(_ value: Bool, for key: SettingsKey)
    func date(for key: SettingsKey) -> Date?
    func set(_ value: Date?, for key: SettingsKey)
}

final class UserDefaultsSettingsRepository: SettingsRepository {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func bool(for key: SettingsKey) -> Bool {
        userDefaults.bool(forKey: key.rawValue)
    }

    func set(_ value: Bool, for key: SettingsKey) {
        userDefaults.set(value, forKey: key.rawValue)
    }

    func date(for key: SettingsKey) -> Date? {
        userDefaults.object(forKey: key.rawValue) as? Date
    }

    func set(_ value: Date?, for key: SettingsKey) {
        if let value {
            userDefaults.set(value, forKey: key.rawValue)
        } else {
            userDefaults.removeObject(forKey: key.rawValue)
        }
    }
}
