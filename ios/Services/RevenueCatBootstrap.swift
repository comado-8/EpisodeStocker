import Foundation

#if canImport(RevenueCat)
import RevenueCat
#endif

enum RevenueCatBootstrap {
    private static let configurationLock = NSLock()
    private static var hasAttemptedConfiguration = false

    static func configureIfNeeded() {
        guard markConfigurationAttemptIfNeeded() else { return }

        #if canImport(RevenueCat)
        guard RevenueCatConfig.hasPublicAPIKey else {
            let environment = ProcessInfo.processInfo.environment
            if environment["XCTestConfigurationFilePath"] != nil {
                return
            }

            #if DEBUG
            NSLog("RevenueCat disabled: REVENUECAT_API_KEY is missing.")
            #endif
            return
        }

        #if DEBUG
        Purchases.logLevel = .info
        #endif
        Purchases.configure(withAPIKey: RevenueCatConfig.publicAPIKey)
        #endif
    }

    private static func markConfigurationAttemptIfNeeded() -> Bool {
        configurationLock.lock()
        defer { configurationLock.unlock() }

        guard !hasAttemptedConfiguration else { return false }
        hasAttemptedConfiguration = true
        return true
    }
}
