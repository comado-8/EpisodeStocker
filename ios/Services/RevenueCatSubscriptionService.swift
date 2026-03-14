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

    func fetchStatus(forceRefresh: Bool) async throws -> SubscriptionStatus {
        try ensureConfigured()
        let customerInfo = try await fetchCustomerInfo(forceRefresh: forceRefresh)
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
                plan: plan,
                monthlyEquivalentText: monthlyEquivalentText(for: package.storeProduct, plan: plan)
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
        Purchases.shared.invalidateCustomerInfoCache()
        _ = try await Purchases.shared.restorePurchases()
        return try await fetchStatus(forceRefresh: false)
    }

    private func ensureConfigured() throws {
        guard RevenueCatConfig.hasPublicAPIKey else {
            throw RevenueCatSubscriptionError.notConfigured
        }
    }

    private func fetchCustomerInfo(forceRefresh: Bool) async throws -> CustomerInfo {
        if forceRefresh {
            Purchases.shared.invalidateCustomerInfoCache()
            do {
                _ = try await Purchases.shared.syncPurchases()
            } catch {
                #if DEBUG
                NSLog("RevenueCat syncPurchases on forceRefresh failed: %@", String(describing: error))
                #endif
            }
            return try await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent)
        }
        return try await Purchases.shared.customerInfo(fetchPolicy: .notStaleCachedOrFetched)
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

    private func monthlyEquivalentText(for storeProduct: StoreProduct, plan: SubscriptionStatus.Plan) -> String? {
        guard plan == .yearly else { return nil }
        let monthlyAmount = NSDecimalNumber(decimal: storeProduct.price / Decimal(12))

        let formatter: NumberFormatter
        if let existingFormatter = storeProduct.priceFormatter?.copy() as? NumberFormatter {
            formatter = existingFormatter
        } else {
            let createdFormatter = NumberFormatter()
            createdFormatter.numberStyle = .currency
            createdFormatter.locale = .current
            if let currencyCode = storeProduct.currencyCode {
                createdFormatter.currencyCode = currencyCode
            }
            formatter = createdFormatter
        }

        guard let formatted = formatter.string(from: monthlyAmount) else { return nil }
        let perMonthPrefix = NSLocalizedString(
            "subscription.monthly_equivalent.prefix",
            tableName: nil,
            bundle: .main,
            value: "月あたり",
            comment: "Prefix for monthly equivalent subscription price label"
        )
        return "\(perMonthPrefix) \(formatted)"
    }

    private func mapStatus(from customerInfo: CustomerInfo) -> SubscriptionStatus {
        guard let entitlement = customerInfo.entitlements.all[RevenueCatConfig.proEntitlementID],
              entitlement.isActive
        else {
            return SubscriptionStatus(plan: .free, expiryDate: nil, trialEndDate: nil)
        }

        let knownCandidates = knownSubscriptionCandidates(
            from: customerInfo.subscriptionsByProductIdentifier
        )
        let currentCandidate = deriveStatusFromSubscriptions(candidates: knownCandidates)
        let entitlementPlan = SubscriptionCatalog.plan(for: entitlement.productIdentifier)
        if entitlementPlan == nil && currentCandidate == nil {
            #if DEBUG
            NSLog(
                "RevenueCat plan mapping fallback: unresolved productIdentifier=%@ entitlement=%@ expiration=%@",
                entitlement.productIdentifier,
                RevenueCatConfig.proEntitlementID,
                String(describing: entitlement.expirationDate)
            )
            #endif
        }

        let plan = entitlementPlan ?? currentCandidate?.plan ?? .monthly
        let expiryDate = entitlement.expirationDate ?? currentCandidate?.subscription.expiresDate
        let willAutoRenew = resolveWillAutoRenew(
            candidates: knownCandidates,
            entitlementProductID: entitlement.productIdentifier,
            currentPlan: plan
        )
        let pendingPlanStatus = derivePendingPlanFromSubscriptions(
            candidates: knownCandidates,
            currentPlan: plan,
            currentExpiryDate: expiryDate
        )

        return SubscriptionStatus(
            plan: plan,
            expiryDate: expiryDate,
            trialEndDate: nil,
            nextPlan: pendingPlanStatus?.plan,
            nextPlanEffectiveDate: pendingPlanStatus?.effectiveDate,
            willAutoRenew: willAutoRenew
        )
    }

    private struct SubscriptionCandidate {
        let plan: SubscriptionStatus.Plan
        let subscription: SubscriptionInfo
    }

    private func knownSubscriptionCandidates(
        from subscriptionsByProductIdentifier: [ProductIdentifier: SubscriptionInfo]
    ) -> [SubscriptionCandidate] {
        subscriptionsByProductIdentifier.compactMap { productID, subscription -> SubscriptionCandidate? in
            guard let plan = SubscriptionCatalog.plan(for: productID) else { return nil }
            return SubscriptionCandidate(plan: plan, subscription: subscription)
        }
    }

    private func deriveStatusFromSubscriptions(
        candidates: [SubscriptionCandidate]
    ) -> SubscriptionCandidate? {
        guard !candidates.isEmpty else { return nil }

        let activeCandidates = candidates.filter { $0.subscription.isActive }
        let renewingCandidates = candidates.filter { $0.subscription.willRenew }

        let candidatePool: [SubscriptionCandidate]
        if !activeCandidates.isEmpty {
            candidatePool = activeCandidates
        } else if !renewingCandidates.isEmpty {
            candidatePool = renewingCandidates
        } else {
            candidatePool = candidates
        }

        return sortCandidatesByPriority(candidatePool).first
    }

    private func derivePendingPlanFromSubscriptions(
        candidates: [SubscriptionCandidate],
        currentPlan: SubscriptionStatus.Plan,
        currentExpiryDate: Date?
    ) -> (plan: SubscriptionStatus.Plan, effectiveDate: Date?)? {
        guard let currentExpiryDate else { return nil }
        guard let currentActive = sortCandidatesByPriority(
            candidates.filter { $0.plan == currentPlan && $0.subscription.isActive }
        ).first else {
            return nil
        }
        guard currentActive.subscription.willRenew == false else {
            return nil
        }
        // Conservative policy: if user already cancelled the current plan, never infer "next plan".
        guard currentActive.subscription.unsubscribeDetectedAt == nil else {
            return nil
        }
        let currentPurchaseDate = currentActive.subscription.purchaseDate

        let pendingCandidates = candidates.filter { candidate in
            guard candidate.plan != currentPlan else { return false }
            guard candidate.subscription.isActive == false else { return false }
            guard candidate.subscription.willRenew else { return false }
            guard candidate.subscription.unsubscribeDetectedAt == nil else { return false }
            guard let pendingExpiry = candidate.subscription.expiresDate else { return false }
            guard pendingExpiry > currentExpiryDate else { return false }
            guard candidate.subscription.purchaseDate > currentPurchaseDate else { return false }
            return true
        }
        guard let pending = sortCandidatesByPriority(pendingCandidates).first else {
            return nil
        }

        return (pending.plan, currentExpiryDate)
    }

    private func resolveWillAutoRenew(
        candidates: [SubscriptionCandidate],
        entitlementProductID: ProductIdentifier,
        currentPlan: SubscriptionStatus.Plan
    ) -> Bool? {
        if let entitlementPlan = SubscriptionCatalog.plan(for: entitlementProductID),
           let entitlementCandidate = sortCandidatesByPriority(
               candidates.filter { $0.plan == entitlementPlan && $0.subscription.isActive }
           ).first
        {
            return entitlementCandidate.subscription.willRenew
        }

        return sortCandidatesByPriority(
            candidates.filter { $0.plan == currentPlan && $0.subscription.isActive }
        ).first?.subscription.willRenew
    }

    private func sortCandidatesByPriority(
        _ candidates: [SubscriptionCandidate]
    ) -> [SubscriptionCandidate] {
        candidates.sorted { lhs, rhs in
            let leftExpiry = lhs.subscription.expiresDate ?? .distantPast
            let rightExpiry = rhs.subscription.expiresDate ?? .distantPast
            if leftExpiry != rightExpiry {
                return leftExpiry > rightExpiry
            }

            let leftPurchase = lhs.subscription.purchaseDate
            let rightPurchase = rhs.subscription.purchaseDate
            if leftPurchase != rightPurchase {
                return leftPurchase > rightPurchase
            }

            return planPriority(lhs.plan) > planPriority(rhs.plan)
        }
    }

    private func planPriority(_ plan: SubscriptionStatus.Plan) -> Int {
        switch plan {
        case .free:
            return 0
        case .monthly:
            return 1
        case .yearly:
            return 2
        }
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
