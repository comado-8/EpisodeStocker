import SwiftData
import SwiftUI

@MainActor
final class AppPreferencesStore: ObservableObject {
    enum ThemeMode: Int, CaseIterable {
        case system
        case light
        case dark

        var preferredColorScheme: ColorScheme? {
            switch self {
            case .system:
                return nil
            case .light:
                return .light
            case .dark:
                return .dark
            }
        }
    }

    enum AutoLockInterval: Int, CaseIterable, Identifiable {
        case immediately = 0
        case seconds30 = 30
        case minutes1 = 60
        case minutes2 = 120
        case minutes5 = 300
        case minutes10 = 600

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .immediately:
                return "すぐに"
            case .seconds30:
                return "30秒"
            case .minutes1:
                return "1分"
            case .minutes2:
                return "2分"
            case .minutes5:
                return "5分"
            case .minutes10:
                return "10分"
            }
        }
    }

    private enum Key {
        static let passcodeEnabled = "settings.security.passcodeEnabled"
        static let biometricEnabled = "settings.security.biometricEnabled"
        static let autoLockInterval = "settings.security.autoLockIntervalSeconds"
        static let themeMode = "settings.display.themeMode"
    }

    private let userDefaults: UserDefaults

    @Published var passcodeEnabled: Bool {
        didSet { userDefaults.set(passcodeEnabled, forKey: Key.passcodeEnabled) }
    }
    @Published var biometricEnabled: Bool {
        didSet { userDefaults.set(biometricEnabled, forKey: Key.biometricEnabled) }
    }
    @Published var autoLockInterval: AutoLockInterval {
        didSet { userDefaults.set(autoLockInterval.rawValue, forKey: Key.autoLockInterval) }
    }
    @Published var themeMode: ThemeMode {
        didSet { userDefaults.set(themeMode.rawValue, forKey: Key.themeMode) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        passcodeEnabled = userDefaults.object(forKey: Key.passcodeEnabled) as? Bool ?? true
        biometricEnabled = userDefaults.object(forKey: Key.biometricEnabled) as? Bool ?? false
        if let storedInterval = AutoLockInterval(rawValue: userDefaults.integer(forKey: Key.autoLockInterval)),
           userDefaults.object(forKey: Key.autoLockInterval) != nil
        {
            autoLockInterval = storedInterval
        } else {
            autoLockInterval = .minutes2
        }
        if let storedThemeMode = ThemeMode(rawValue: userDefaults.integer(forKey: Key.themeMode)),
           userDefaults.object(forKey: Key.themeMode) != nil
        {
            themeMode = storedThemeMode
        } else {
            themeMode = .system
        }
    }

    var preferredColorScheme: ColorScheme? {
        themeMode.preferredColorScheme
    }

    var isAutoLockConfigEnabled: Bool {
        passcodeEnabled || biometricEnabled
    }
}

@main
struct EpisodeStockerApp: App {
    @StateObject private var store = EpisodeStore()
    @StateObject private var router = AppRouter()
    @StateObject private var premiumAccess = PremiumAccessViewModel()
    @StateObject private var appPreferences = AppPreferencesStore()
    private let modelContainer: ModelContainer
    private let seedProfile: SeedData.Profile
    private let shouldSeedSampleData: Bool
    private var effectiveCloudSyncEnabled: Bool

    init() {
        RevenueCatBootstrap.configureIfNeeded()

        let environment = ProcessInfo.processInfo.environment
        let isRunningTests = environment["XCTestConfigurationFilePath"] != nil
        let settingsRepository = UserDefaultsSettingsRepository()
        if !isRunningTests {
            settingsRepository.set(false, for: .cloudSyncRuntimeDisabled)
        }
        let cloudSyncModeResolver = DefaultCloudSyncModeResolver()
        var resolvedEffectiveCloudSyncEnabled =
            !isRunningTests && cloudSyncModeResolver.resolveEffectiveCloudSyncEnabled()
        if !settingsRepository.bool(for: .cloudSyncMigrationPrepared) {
            resolvedEffectiveCloudSyncEnabled = false
        }
        #if targetEnvironment(simulator)
        let isSimulatorEnvironment = true
        #else
        let isSimulatorEnvironment = false
        #endif
        let shouldSeedOnCurrentDevice = Self.shouldSeedSampleData(
            isRunningTests: isRunningTests,
            isSimulator: isSimulatorEnvironment
        )
        #if DEBUG
        #if targetEnvironment(simulator)
        if isRunningTests {
            seedProfile = .minimal
        } else {
            seedProfile = .simulatorComprehensive
        }
        #else
        seedProfile = .minimal
        #endif
        #else
        seedProfile = .minimal
        #endif

        let resolvedModelContainer: ModelContainer
        do {
            resolvedModelContainer = try Self.makeContainer(
                isStoredInMemoryOnly: isRunningTests,
                effectiveCloudSyncEnabled: resolvedEffectiveCloudSyncEnabled
            )
        } catch {
            if resolvedEffectiveCloudSyncEnabled {
                NSLog(
                    "Cloud-enabled ModelContainer load failed. Falling back to local-only store: %@",
                    String(describing: error)
                )
                do {
                    resolvedModelContainer = try Self.makeContainer(
                        isStoredInMemoryOnly: isRunningTests,
                        effectiveCloudSyncEnabled: false
                    )
                    resolvedEffectiveCloudSyncEnabled = false
                    if !isRunningTests {
                        settingsRepository.set(true, for: .cloudSyncRuntimeDisabled)
                    }
                } catch {
                    do {
                        if let fallbackContainer = try Self.createInMemoryFallbackIfSupported(
                            isRunningTests: isRunningTests,
                            error: error
                        ) {
                            resolvedModelContainer = fallbackContainer
                            resolvedEffectiveCloudSyncEnabled = false
                        } else {
                            fatalError("Failed to create ModelContainer: \(error)")
                        }
                    } catch {
                        fatalError("Failed to create fallback in-memory ModelContainer: \(error)")
                    }
                }
            } else {
                do {
                    if let fallbackContainer = try Self.createInMemoryFallbackIfSupported(
                        isRunningTests: isRunningTests,
                        error: error
                    ) {
                        resolvedModelContainer = fallbackContainer
                        resolvedEffectiveCloudSyncEnabled = false
                    } else {
                        fatalError("Failed to create ModelContainer: \(error)")
                    }
                } catch {
                    fatalError("Failed to create fallback in-memory ModelContainer: \(error)")
                }
            }
        }
        self.modelContainer = resolvedModelContainer
        self.shouldSeedSampleData = shouldSeedOnCurrentDevice
        self.effectiveCloudSyncEnabled = resolvedEffectiveCloudSyncEnabled
    }

    private static func makeContainer(
        isStoredInMemoryOnly: Bool,
        effectiveCloudSyncEnabled: Bool
    ) throws -> ModelContainer {
        let cloudKitContainerIdentifier = "iCloud.com.comado-studio.EpisodeStocker"
        let cloudDatabase: ModelConfiguration.CloudKitDatabase = if !isStoredInMemoryOnly && effectiveCloudSyncEnabled {
            .private(cloudKitContainerIdentifier)
        } else {
            .none
        }
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            cloudKitDatabase: cloudDatabase
        )
        return try ModelContainer(
            for: Episode.self,
            UnlockLog.self,
            Tag.self,
            Person.self,
            Project.self,
            Emotion.self,
            Place.self,
            configurations: configuration
        )
    }

    private static func createInMemoryFallbackIfSupported(
        isRunningTests: Bool,
        error: Error
    ) throws -> ModelContainer? {
        #if DEBUG
        #if targetEnvironment(simulator)
        guard !isRunningTests else { return nil }
        NSLog(
            "Persistent ModelContainer load failed on simulator. Falling back to in-memory: \(String(describing: error))"
        )
        return try makeContainer(
            isStoredInMemoryOnly: true,
            effectiveCloudSyncEnabled: false
        )
        #else
        return nil
        #endif
        #else
        return nil
        #endif
    }

    static func shouldSeedSampleData(isRunningTests: Bool, isSimulator: Bool) -> Bool {
        isRunningTests || isSimulator
    }

    var body: some Scene {
        WindowGroup {
            RootTabContainer(
                seedProfile: seedProfile,
                shouldSeedSampleData: shouldSeedSampleData,
                effectiveCloudSyncEnabled: effectiveCloudSyncEnabled
            )
                .environmentObject(store)
                .environmentObject(router)
                .environmentObject(premiumAccess)
                .environmentObject(appPreferences)
                .modelContainer(modelContainer)
        }
    }
}

private struct RootTabContainer: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var premiumAccess: PremiumAccessViewModel
    @EnvironmentObject private var appPreferences: AppPreferencesStore
    @StateObject private var cloudSyncStatusKeeper = CloudSyncStatusKeeper()
    let seedProfile: SeedData.Profile
    let shouldSeedSampleData: Bool
    let effectiveCloudSyncEnabled: Bool

    var body: some View {
        RootTabView()
            .preferredColorScheme(appPreferences.preferredColorScheme)
            .task {
                let preparationService = CloudSyncDataPreparationService(modelContext: modelContext)
                preparationService.prepareIfNeeded()
                if shouldSeedSampleData {
                    SeedData.seedIfNeeded(
                        context: modelContext,
                        profile: seedProfile,
                        isCloudSyncEnabled: effectiveCloudSyncEnabled
                    )
                }
                cloudSyncStatusKeeper.start()
            }
            .task { await premiumAccess.ensureStatusLoaded() }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await premiumAccess.refresh(forceRefresh: true) }
            }
    }
}

@MainActor
private final class CloudSyncStatusKeeper: ObservableObject {
    private let monitor: CloudSyncStatusMonitoring

    init(monitor: CloudSyncStatusMonitoring = CloudSyncStatusMonitor()) {
        self.monitor = monitor
    }

    func start() {
        monitor.start()
    }
}
