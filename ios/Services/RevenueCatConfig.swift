import Foundation

enum RevenueCatConfig {
    static let apiKeyEnvironmentVariable = "REVENUECAT_API_KEY"
    static let apiKeyInfoPlistKey = "REVENUECAT_API_KEY"

    static var publicAPIKey: String {
        if let environmentAPIKey = sanitizedAPIKey(
            ProcessInfo.processInfo.environment[apiKeyEnvironmentVariable]
        ) {
            return environmentAPIKey
        }

        if let infoPlistAPIKey = sanitizedAPIKey(
            Bundle.main.object(forInfoDictionaryKey: apiKeyInfoPlistKey) as? String
        ) {
            return infoPlistAPIKey
        }

        return ""
    }

    static var hasPublicAPIKey: Bool {
        !publicAPIKey.isEmpty
    }

    private static func sanitizedAPIKey(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.contains("$(") else { return nil }
        return trimmed
    }

    // Entitlement configured in RevenueCat Dashboard.
    static let proEntitlementID = "EpisodeStocker Pro"

    // Offering/package identifiers configured in RevenueCat Dashboard.
    static let defaultOfferingID = "default"
    static let monthlyPackageID = "monthly"
    static let yearlyPackageID = "yearly"
}
