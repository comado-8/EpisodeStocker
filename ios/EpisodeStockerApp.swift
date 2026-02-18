import SwiftData
import SwiftUI

@main
struct EpisodeStockerApp: App {
    @StateObject private var store = EpisodeStore()
    @StateObject private var router = AppRouter()
    private let modelContainer: ModelContainer
    private let seedProfile: SeedData.Profile

    init() {
        let environment = ProcessInfo.processInfo.environment
        let isRunningTests = environment["XCTestConfigurationFilePath"] != nil
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: isRunningTests,
            cloudKitDatabase: .none
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

        do {
            modelContainer = try ModelContainer(
                for: Episode.self,
                UnlockLog.self,
                Tag.self,
                Person.self,
                Project.self,
                Emotion.self,
                Place.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabContainer(seedProfile: seedProfile)
                .environmentObject(store)
                .environmentObject(router)
                .modelContainer(modelContainer)
        }
    }
}

private struct RootTabContainer: View {
    @Environment(\.modelContext) private var modelContext
    let seedProfile: SeedData.Profile

    var body: some View {
        RootTabView()
            .task { SeedData.seedIfNeeded(context: modelContext, profile: seedProfile) }
    }
}
