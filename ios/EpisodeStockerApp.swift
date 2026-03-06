import SwiftData
import SwiftUI

@main
struct EpisodeStockerApp: App {
    @StateObject private var store = EpisodeStore()
    @StateObject private var router = AppRouter()
    @StateObject private var premiumAccess = PremiumAccessViewModel()
    private let modelContainer: ModelContainer
    private let seedProfile: SeedData.Profile
    private let effectiveCloudSyncEnabled: Bool

    init() {
        RevenueCatBootstrap.configureIfNeeded()

        let environment = ProcessInfo.processInfo.environment
        let isRunningTests = environment["XCTestConfigurationFilePath"] != nil
        let cloudSyncModeResolver = DefaultCloudSyncModeResolver()
        effectiveCloudSyncEnabled = !isRunningTests && cloudSyncModeResolver.resolveEffectiveCloudSyncEnabled()
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

        do {
            modelContainer = try Self.makeContainer(
                isStoredInMemoryOnly: isRunningTests,
                effectiveCloudSyncEnabled: effectiveCloudSyncEnabled
            )
        } catch {
            #if DEBUG
            #if targetEnvironment(simulator)
            if !isRunningTests {
                NSLog(
                    "Persistent ModelContainer load failed on simulator. Falling back to in-memory: \(String(describing: error))"
                )
                do {
                    modelContainer = try Self.makeContainer(
                        isStoredInMemoryOnly: true,
                        effectiveCloudSyncEnabled: false
                    )
                    return
                } catch {
                    fatalError("Failed to create fallback in-memory ModelContainer: \(error)")
                }
            }
            #endif
            #endif
            fatalError("Failed to create ModelContainer: \(error)")
        }
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

    var body: some Scene {
        WindowGroup {
            RootTabContainer(
                seedProfile: seedProfile,
                effectiveCloudSyncEnabled: effectiveCloudSyncEnabled
            )
                .environmentObject(store)
                .environmentObject(router)
                .environmentObject(premiumAccess)
                .modelContainer(modelContainer)
        }
    }
}

private struct RootTabContainer: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var premiumAccess: PremiumAccessViewModel
    let seedProfile: SeedData.Profile
    let effectiveCloudSyncEnabled: Bool

    var body: some View {
        RootTabView()
            .preferredColorScheme(.light)
            .task {
                SeedData.seedIfNeeded(
                    context: modelContext,
                    profile: seedProfile,
                    isCloudSyncEnabled: effectiveCloudSyncEnabled
                )
            }
            .task { await premiumAccess.ensureStatusLoaded() }
    }
}
