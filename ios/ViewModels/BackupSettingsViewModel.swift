import Foundation
import SwiftUI

@MainActor
/// UI state holder for backup entitlement, availability, toggle state, and manual backup progress.
/// It enforces subscription constraints before delegating operations to `CloudBackupService`.
final class BackupSettingsViewModel: ObservableObject {
    @Published private(set) var subscriptionStatus: SubscriptionStatus
    @Published private(set) var availability: CloudBackupAvailability = .unavailable(reason: "確認中")
    @Published private(set) var isBackupEnabled = false
    @Published private(set) var lastBackupAt: Date?
    @Published private(set) var isRunningBackup = false
    @Published var errorMessage: String?

    private let cloudBackupService: CloudBackupService

    init(
        cloudBackupService: CloudBackupService,
        subscriptionStatus: SubscriptionStatus = SubscriptionStatus(plan: .free, expiryDate: nil, trialEndDate: nil)
    ) {
        self.cloudBackupService = cloudBackupService
        self.subscriptionStatus = subscriptionStatus
        self.isBackupEnabled = cloudBackupService.isBackupEnabled()
        self.lastBackupAt = cloudBackupService.lastBackupAt()
    }

    var canUseBackup: Bool {
        if subscriptionStatus.plan != .free {
            return true
        }
        guard let trialEndDate = subscriptionStatus.trialEndDate else {
            return false
        }
        return trialEndDate > Date()
    }

    var availabilityMessage: String {
        switch availability {
        case .available:
            return "利用可能"
        case .unavailable(let reason):
            return reason
        }
    }

    func updateSubscriptionStatus(_ status: SubscriptionStatus) {
        subscriptionStatus = status
    }

    func load() async {
        availability = await cloudBackupService.availability()
        isBackupEnabled = cloudBackupService.isBackupEnabled()
        lastBackupAt = cloudBackupService.lastBackupAt()
    }

    func setBackupEnabled(_ enabled: Bool) {
        guard enabled else {
            do {
                try cloudBackupService.setBackupEnabled(false)
                isBackupEnabled = false
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        guard canUseBackup else {
            errorMessage = CloudBackupError.notEntitled.localizedDescription
            return
        }

        switch availability {
        case .available:
            do {
                try cloudBackupService.setBackupEnabled(true)
                isBackupEnabled = true
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        case .unavailable(let reason):
            errorMessage = CloudBackupError.unavailable(reason: reason).localizedDescription
        }
    }

    func runManualBackup() async {
        guard isBackupEnabled else {
            errorMessage = CloudBackupError.backupDisabled.localizedDescription
            return
        }

        guard canUseBackup else {
            errorMessage = CloudBackupError.notEntitled.localizedDescription
            return
        }

        switch availability {
        case .available:
            break
        case .unavailable(let reason):
            errorMessage = CloudBackupError.unavailable(reason: reason).localizedDescription
            return
        }

        isRunningBackup = true
        defer { isRunningBackup = false }

        do {
            lastBackupAt = try await cloudBackupService.runManualBackup()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
