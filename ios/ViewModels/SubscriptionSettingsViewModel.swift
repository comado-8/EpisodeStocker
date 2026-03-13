import Foundation
import SwiftUI

@MainActor
/// UI state holder for subscription plan, purchasable products, loading, and error messaging.
/// It coordinates fetch, purchase, and restore actions through `SubscriptionService`.
final class SubscriptionSettingsViewModel: ObservableObject {
    @Published private(set) var status: SubscriptionStatus
    @Published private(set) var products: [SubscriptionProduct]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: SubscriptionService

    init(
        service: SubscriptionService,
        initialStatus: SubscriptionStatus = SubscriptionStatus(plan: .free, expiryDate: nil, trialEndDate: nil),
        initialProducts: [SubscriptionProduct] = []
    ) {
        self.service = service
        self.status = initialStatus
        self.products = initialProducts
    }

    var trialRemainingDays: Int {
        guard let trialEndDate = status.trialEndDate else { return 0 }
        let seconds = trialEndDate.timeIntervalSince(Date())
        guard seconds > 0 else { return 0 }
        return Int(ceil(seconds / 86_400))
    }

    var hasPremiumAccess: Bool {
        status.plan != .free || trialRemainingDays > 0
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let currentStatus = service.fetchStatus(forceRefresh: false)
            async let currentProducts = service.fetchProducts()
            let (newStatus, newProducts) = try await (currentStatus, currentProducts)
            status = newStatus
            products = newProducts
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(productID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let outcome = try await service.purchase(productID: productID)
            switch outcome {
            case .purchased(let newStatus):
                status = newStatus
                if let refreshedStatus = try? await service.fetchStatus(forceRefresh: true) {
                    status = refreshedStatus
                }
                errorMessage = nil
            case .purchasedStatusUnavailable(let productID):
                if let refreshedStatus = try? await service.fetchStatus(forceRefresh: true) {
                    status = refreshedStatus
                    errorMessage = nil
                } else {
                    errorMessage = "購入は完了しましたが、最新状態の取得に失敗しました。(商品ID: \(productID))"
                }
            case .userCancelled:
                errorMessage = "購入はキャンセルされました。"
            case .pending:
                errorMessage = "購入は保留中です。"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await service.restorePurchases()
            status = try await service.fetchStatus(forceRefresh: true)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshStatus(forceRefresh: Bool = false) async {
        guard !isLoading else { return }
        do {
            status = try await service.fetchStatus(forceRefresh: forceRefresh)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshProducts() async {
        guard !isLoading else { return }
        do {
            products = try await service.fetchProducts()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
