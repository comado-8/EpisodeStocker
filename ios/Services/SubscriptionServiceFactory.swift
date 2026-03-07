import Foundation

enum SubscriptionServiceFactory {
    static func makeService(
        hasRevenueCatSDK: Bool,
        hasPublicAPIKey: Bool,
        configureRevenueCat: () -> Void,
        makeRevenueCatService: () -> SubscriptionService,
        makeStoreKitService: () -> SubscriptionService
    ) -> SubscriptionService {
        guard hasRevenueCatSDK, hasPublicAPIKey else {
            return makeStoreKitService()
        }

        configureRevenueCat()
        return makeRevenueCatService()
    }

    static func makeService() -> SubscriptionService {
        #if canImport(RevenueCat)
        let hasRevenueCatSDK = true
        #else
        let hasRevenueCatSDK = false
        #endif

        return makeService(
            hasRevenueCatSDK: hasRevenueCatSDK,
            hasPublicAPIKey: RevenueCatConfig.hasPublicAPIKey,
            configureRevenueCat: {
                #if canImport(RevenueCat)
                RevenueCatBootstrap.configureIfNeeded()
                #endif
            },
            makeRevenueCatService: {
                #if canImport(RevenueCat)
                return RevenueCatSubscriptionService()
                #else
                return StoreKitSubscriptionService()
                #endif
            },
            makeStoreKitService: {
                StoreKitSubscriptionService()
            }
        )
    }
}
