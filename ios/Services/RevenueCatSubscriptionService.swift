import Foundation

#if canImport(RevenueCat)
import RevenueCat

enum RevenueCatSubscriptionError: LocalizedError {
    case notConfigured
    case offeringNotFound
    case productNotFound(productID: String)
    case customerInfoUnavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "課金設定が未完了です。REVENUECAT_API_KEY を確認してください。"
        case .offeringNotFound:
            return "課金商品の取得に失敗しました。RevenueCat Offering 設定を確認してください。"
        case .productNotFound(let productID):
            return "課金商品が見つかりません: \(productID)"
        case .customerInfoUnavailable:
            return "購入後の顧客情報取得に失敗しました。"
        }
    }
}

final class RevenueCatSubscriptionService: SubscriptionService {
    init() {
        RevenueCatBootstrap.configureIfNeeded()
    }

    func fetchStatus() async throws -> SubscriptionStatus {
        try ensureConfigured()
        let customerInfo = try await fetchCustomerInfo()
        return mapStatus(from: customerInfo)
    }

    func fetchProducts() async throws -> [SubscriptionProduct] {
        try ensureConfigured()
        let offerings = try await fetchOfferings()
        guard let offering = selectOffering(from: offerings) else {
            throw RevenueCatSubscriptionError.offeringNotFound
        }

        let mappedProducts = offering.availablePackages.compactMap { package -> SubscriptionProduct? in
            let productID = package.storeProduct.productIdentifier
            guard let plan = plan(for: package, productID: productID) else { return nil }
            return SubscriptionProduct(
                id: productID,
                displayName: package.storeProduct.localizedTitle,
                displayPrice: package.storeProduct.localizedPriceString,
                plan: plan
            )
        }

        let order = [SubscriptionCatalog.monthlyProductID, SubscriptionCatalog.yearlyProductID]
        return mappedProducts.sorted { lhs, rhs in
            let left = order.firstIndex(of: lhs.id) ?? Int.max
            let right = order.firstIndex(of: rhs.id) ?? Int.max
            return left < right
        }
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        try ensureConfigured()
        let offerings = try await fetchOfferings()
        guard let offering = selectOffering(from: offerings) else {
            throw RevenueCatSubscriptionError.offeringNotFound
        }
        guard let package = selectPackage(from: offering, productID: productID) else {
            throw RevenueCatSubscriptionError.productNotFound(productID: productID)
        }

        let purchaseResult = try await purchase(package: package)
        switch purchaseResult {
        case .purchased(let customerInfo):
            return .purchased(mapStatus(from: customerInfo))
        case .cancelled:
            return .userCancelled
        case .pending:
            return .pending
        }
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        try ensureConfigured()
        let customerInfo = try await Purchases.shared.restorePurchases()
        return mapStatus(from: customerInfo)
    }

    private func ensureConfigured() throws {
        guard RevenueCatConfig.hasPublicAPIKey else {
            throw RevenueCatSubscriptionError.notConfigured
        }
    }

    private func fetchCustomerInfo() async throws -> CustomerInfo {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.getCustomerInfo { customerInfo, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let customerInfo else {
                    continuation.resume(throwing: RevenueCatSubscriptionError.customerInfoUnavailable)
                    return
                }
                continuation.resume(returning: customerInfo)
            }
        }
    }

    private func fetchOfferings() async throws -> Offerings {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.getOfferings { offerings, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let offerings else {
                    continuation.resume(throwing: RevenueCatSubscriptionError.offeringNotFound)
                    return
                }
                continuation.resume(returning: offerings)
            }
        }
    }

    private func selectOffering(from offerings: Offerings) -> Offering? {
        offerings.offering(identifier: RevenueCatConfig.defaultOfferingID) ?? offerings.current
    }

    private func selectPackage(from offering: Offering, productID: String) -> Package? {
        offering.availablePackages.first(where: {
            $0.storeProduct.productIdentifier == productID
        })
    }

    private func plan(for package: Package, productID: String) -> SubscriptionStatus.Plan? {
        switch package.identifier {
        case RevenueCatConfig.monthlyPackageID:
            return .monthly
        case RevenueCatConfig.yearlyPackageID:
            return .yearly
        default:
            return SubscriptionCatalog.plan(for: productID)
        }
    }

    private func mapStatus(from customerInfo: CustomerInfo) -> SubscriptionStatus {
        guard let entitlement = customerInfo.entitlements.all[RevenueCatConfig.proEntitlementID],
              entitlement.isActive
        else {
            return SubscriptionStatus(plan: .free, expiryDate: nil, trialEndDate: nil)
        }

        let resolvedPlan = SubscriptionCatalog.plan(for: entitlement.productIdentifier)
        if resolvedPlan == nil {
            NSLog(
                "RevenueCat plan mapping fallback: unresolved productIdentifier=%@ entitlement=%@ expiration=%@",
                entitlement.productIdentifier,
                RevenueCatConfig.proEntitlementID,
                String(describing: entitlement.expirationDate)
            )
        }
        let plan = resolvedPlan ?? .monthly
        return SubscriptionStatus(
            plan: plan,
            expiryDate: entitlement.expirationDate,
            trialEndDate: nil
        )
    }

    private enum RevenueCatPurchaseResult {
        case purchased(CustomerInfo)
        case cancelled
        case pending
    }

    private func purchase(package: Package) async throws -> RevenueCatPurchaseResult {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.purchase(package: package) { _, customerInfo, error, userCancelled in
                if userCancelled {
                    continuation.resume(returning: .cancelled)
                    return
                }
                if let error {
                    if self.isPaymentPendingError(error) {
                        continuation.resume(returning: .pending)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                guard let customerInfo else {
                    continuation.resume(throwing: RevenueCatSubscriptionError.customerInfoUnavailable)
                    return
                }
                continuation.resume(returning: .purchased(customerInfo))
            }
        }
    }

    private func isPaymentPendingError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == ErrorCode.errorDomain else {
            return false
        }
        guard let code = ErrorCode(rawValue: nsError.code) else {
            return false
        }
        return code == .paymentPendingError
    }
}
#endif
