import Foundation

@MainActor
final class ManualBackupSettingsViewModel: ObservableObject {
    static let minimumPassphraseLength = ManualBackupPassphrasePolicy.minimumLength

    @Published private(set) var isExporting = false
    @Published private(set) var isInspecting = false
    @Published private(set) var isRestoring = false
    @Published private(set) var lastExportAt: Date?
    @Published private(set) var lastRestoreAt: Date?
    @Published private(set) var pendingRestorePreview: ManualBackupPreview?
    @Published var errorMessage: String?

    private let manualBackupService: ManualBackupService
    private let settingsRepository: SettingsRepository

    private var pendingRestoreURL: URL?
    private var pendingRestorePassphrase: String?

    init(
        manualBackupService: ManualBackupService,
        settingsRepository: SettingsRepository = UserDefaultsSettingsRepository()
    ) {
        self.manualBackupService = manualBackupService
        self.settingsRepository = settingsRepository
        self.lastExportAt = settingsRepository.date(for: .manualBackupLastExportAt)
        self.lastRestoreAt = settingsRepository.date(for: .manualBackupLastRestoreAt)
    }

    func load() {
        lastExportAt = settingsRepository.date(for: .manualBackupLastExportAt)
        lastRestoreAt = settingsRepository.date(for: .manualBackupLastRestoreAt)
    }

    func exportBackup(passphrase: String, confirmation: String) async -> URL? {
        guard validatePassphrase(passphrase) else {
            errorMessage = ManualBackupError.invalidPassphrase.localizedDescription
            return nil
        }
        guard passphrase == confirmation else {
            errorMessage = "確認用パスフレーズが一致しません。"
            return nil
        }

        isExporting = true
        defer { isExporting = false }

        do {
            let exportedURL = try await manualBackupService.exportEncryptedBackup(passphrase: passphrase)
            errorMessage = nil
            lastExportAt = settingsRepository.date(for: .manualBackupLastExportAt)
            return exportedURL
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func inspectBackup(at url: URL, passphrase: String) async -> Bool {
        guard validatePassphrase(passphrase) else {
            errorMessage = ManualBackupError.invalidPassphrase.localizedDescription
            return false
        }

        isInspecting = true
        defer { isInspecting = false }

        do {
            let preview = try await manualBackupService.inspectEncryptedBackup(at: url, passphrase: passphrase)
            pendingRestorePreview = preview
            pendingRestoreURL = url
            pendingRestorePassphrase = passphrase
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restorePendingBackup() async -> ManualRestoreResult? {
        guard let pendingRestoreURL,
              let pendingRestorePassphrase
        else {
            errorMessage = "復元対象のバックアップが選択されていません。"
            return nil
        }

        isRestoring = true
        defer { isRestoring = false }

        do {
            let result = try await manualBackupService.restoreEncryptedBackup(
                at: pendingRestoreURL,
                passphrase: pendingRestorePassphrase
            )
            errorMessage = nil
            lastRestoreAt = settingsRepository.date(for: .manualBackupLastRestoreAt)
            clearPendingRestore()
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func clearPendingRestore() {
        pendingRestorePreview = nil
        pendingRestoreURL = nil
        pendingRestorePassphrase = nil
    }

    private func validatePassphrase(_ passphrase: String) -> Bool {
        passphrase.count >= Self.minimumPassphraseLength
    }
}
