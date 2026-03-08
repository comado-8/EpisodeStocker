import Foundation
import SwiftUI

@MainActor
/// UI state holder for cloud sync entitlement, availability, requested toggle, and sync progress.
/// It enforces subscription constraints before delegating operations to `CloudBackupService`.
final class BackupSettingsViewModel: ObservableObject {
    @Published private(set) var subscriptionStatus: SubscriptionStatus
    @Published private(set) var availability: CloudBackupAvailability = .unavailable(reason: "確認中")
    @Published private(set) var isBackupEnabled = false
    @Published private(set) var lastBackupAt: Date?
    @Published private(set) var isSyncing = false
    @Published private(set) var requiresAppRestartNotice = false
    @Published private(set) var isRunningBackup = false
    @Published var errorMessage: String?

    private let cloudBackupService: CloudBackupService
    private let cloudSyncStatusMonitor: CloudSyncStatusMonitoring
    private let isEntitlementCheckEnabled: Bool

    init(
        cloudBackupService: CloudBackupService,
        cloudSyncStatusMonitor: CloudSyncStatusMonitoring = CloudSyncStatusMonitor(),
        isEntitlementCheckEnabled: Bool = true,
        subscriptionStatus: SubscriptionStatus = SubscriptionStatus(plan: .free, expiryDate: nil, trialEndDate: nil)
    ) {
        self.cloudBackupService = cloudBackupService
        self.cloudSyncStatusMonitor = cloudSyncStatusMonitor
        self.isEntitlementCheckEnabled = isEntitlementCheckEnabled
        self.subscriptionStatus = subscriptionStatus
        self.isBackupEnabled = cloudBackupService.isBackupEnabled()
        self.lastBackupAt = cloudBackupService.lastBackupAt()
        cloudSyncStatusMonitor.onChange = { [weak self] snapshot in
            guard let self else { return }
            self.isSyncing = snapshot.isSyncing
            self.lastBackupAt = snapshot.lastSyncAt
            if let lastErrorMessage = snapshot.lastErrorMessage {
                self.errorMessage = lastErrorMessage
            } else {
                self.errorMessage = nil
            }
        }
    }

    deinit {
        cloudSyncStatusMonitor.stop()
    }

    var canUseBackup: Bool {
        guard isEntitlementCheckEnabled else {
            return true
        }
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

    var needsAppleAccountSignIn: Bool {
        if case .unavailable(let reason) = availability {
            return reason == CloudKitBackupService.appleAccountSignInRequiredReason
        }
        return false
    }

    var lastSyncAt: Date? {
        lastBackupAt
    }

    func updateSubscriptionStatus(_ status: SubscriptionStatus) {
        subscriptionStatus = status
        applyDowngradePolicyIfNeeded()
    }

    func refreshSubscriptionStatus(using service: SubscriptionService) async {
        do {
            let status = try await service.fetchStatus()
            updateSubscriptionStatus(status)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func load() async {
        availability = await cloudBackupService.availability()
        isBackupEnabled = cloudBackupService.isBackupEnabled()
        lastBackupAt = cloudBackupService.lastBackupAt()
        applyDowngradePolicyIfNeeded()
        cloudSyncStatusMonitor.start()
    }

    func setBackupEnabled(_ enabled: Bool) {
        guard enabled else {
            do {
                let previous = isBackupEnabled
                try cloudBackupService.setBackupEnabled(false)
                isBackupEnabled = false
                errorMessage = nil
                if previous != isBackupEnabled {
                    requiresAppRestartNotice = true
                }
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
                let previous = isBackupEnabled
                try cloudBackupService.setBackupEnabled(true)
                isBackupEnabled = true
                errorMessage = nil
                if previous != isBackupEnabled {
                    requiresAppRestartNotice = true
                }
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

    private func applyDowngradePolicyIfNeeded() {
        guard !canUseBackup, isBackupEnabled else { return }
        do {
            try cloudBackupService.setBackupEnabled(false)
            isBackupEnabled = false
            requiresAppRestartNotice = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
