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
    @Published private(set) var isInitialSubscriptionResolving = true
    @Published private(set) var isInitialLoadingOverlayVisible = true
    @Published var errorMessage: String?

    private let cloudBackupService: CloudBackupService
    private let cloudSyncStatusMonitor: CloudSyncStatusMonitoring
    private let isEntitlementCheckEnabled: Bool
    private let initialLoadingOverlayTimeout: Duration
    private let minimumInitialLoadingVisibleDuration: Duration
    private let clock = ContinuousClock()
    private var hasResolvedSubscriptionStatus = false
    private var hasStartedInitialResolution = false
    private var initialResolutionStartedAt: ContinuousClock.Instant?
    private var initialLoadingTimeoutTask: Task<Void, Never>?
    private var initialResolutionCompletionTask: Task<Void, Never>?

    init(
        cloudBackupService: CloudBackupService,
        cloudSyncStatusMonitor: CloudSyncStatusMonitoring = CloudSyncStatusMonitor(),
        isEntitlementCheckEnabled: Bool = true,
        initialLoadingOverlayTimeout: Duration = .seconds(8),
        minimumInitialLoadingVisibleDuration: Duration = .zero,
        subscriptionStatus: SubscriptionStatus = SubscriptionStatus(plan: .free, expiryDate: nil, trialEndDate: nil)
    ) {
        self.cloudBackupService = cloudBackupService
        self.cloudSyncStatusMonitor = cloudSyncStatusMonitor
        self.isEntitlementCheckEnabled = isEntitlementCheckEnabled
        self.initialLoadingOverlayTimeout = initialLoadingOverlayTimeout
        self.minimumInitialLoadingVisibleDuration = minimumInitialLoadingVisibleDuration
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
        initialLoadingTimeoutTask?.cancel()
        initialResolutionCompletionTask?.cancel()
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

    var hasBackupAccess: Bool {
        canUseBackup
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

    var isSyncInteractionDisabled: Bool {
        isInitialSubscriptionResolving
    }

    func loadInitialState(using service: SubscriptionService) async {
        beginInitialSubscriptionResolutionIfNeeded()
        await load()
        await refreshSubscriptionStatus(using: service)
    }

    func updateSubscriptionStatus(_ status: SubscriptionStatus) {
        subscriptionStatus = status
        hasResolvedSubscriptionStatus = true
        completeInitialSubscriptionResolution()
        applyDowngradePolicyIfNeeded()
    }

    func refreshSubscriptionStatus(using service: SubscriptionService) async {
        let needsInitialResolutionCompletion = !hasResolvedSubscriptionStatus
        if needsInitialResolutionCompletion {
            beginInitialSubscriptionResolutionIfNeeded()
        }
        defer {
            if needsInitialResolutionCompletion, isInitialSubscriptionResolving {
                completeInitialSubscriptionResolution()
            }
        }
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
        // Avoid writing user preferences based on the initializer's placeholder status.
        // We only enforce downgrade after an actual subscription status has been resolved.
        guard hasResolvedSubscriptionStatus else { return }
        guard !canUseBackup, isBackupEnabled else { return }
        do {
            try cloudBackupService.setBackupEnabled(false)
            isBackupEnabled = false
            requiresAppRestartNotice = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func beginInitialSubscriptionResolutionIfNeeded() {
        guard !hasStartedInitialResolution else { return }
        hasStartedInitialResolution = true
        initialResolutionStartedAt = clock.now
        isInitialSubscriptionResolving = true
        isInitialLoadingOverlayVisible = true
        startInitialLoadingTimeout()
    }

    private func completeInitialSubscriptionResolution() {
        initialLoadingTimeoutTask?.cancel()
        initialLoadingTimeoutTask = nil
        initialResolutionCompletionTask?.cancel()

        let startedAt = initialResolutionStartedAt
        let minimumVisibleDuration = minimumInitialLoadingVisibleDuration
        let clock = self.clock
        let remainingDuration: Duration
        if let startedAt {
            let elapsed = clock.now - startedAt
            if elapsed < minimumVisibleDuration {
                remainingDuration = minimumVisibleDuration - elapsed
            } else {
                remainingDuration = .zero
            }
        } else {
            remainingDuration = .zero
        }

        if remainingDuration == .zero {
            isInitialSubscriptionResolving = false
            isInitialLoadingOverlayVisible = false
            initialResolutionCompletionTask = nil
            return
        }

        initialResolutionCompletionTask = Task { [weak self] in
            try? await Task.sleep(for: remainingDuration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.isInitialSubscriptionResolving = false
                self.isInitialLoadingOverlayVisible = false
                self.initialResolutionCompletionTask = nil
            }
        }
    }

    private func startInitialLoadingTimeout() {
        initialLoadingTimeoutTask?.cancel()
        let timeout = initialLoadingOverlayTimeout
        initialLoadingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.isInitialSubscriptionResolving else { return }
                self.isInitialLoadingOverlayVisible = false
            }
        }
    }
}
