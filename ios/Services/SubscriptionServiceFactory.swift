import Foundation

enum SubscriptionServiceFactory {
    static func makeService() -> SubscriptionService {
        #if canImport(RevenueCat)
        if RevenueCatConfig.hasPublicAPIKey {
            RevenueCatBootstrap.configureIfNeeded()
            return RevenueCatSubscriptionService()
        }
        #endif
        return StoreKitSubscriptionService()
    }
}
