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
            async let currentStatus = service.fetchStatus()
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
                errorMessage = nil
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
            status = try await service.restorePurchases()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
