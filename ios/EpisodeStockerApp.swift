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
            modelContainer = try Self.makeContainer(isStoredInMemoryOnly: isRunningTests)
        } catch {
            #if DEBUG
            #if targetEnvironment(simulator)
            if !isRunningTests {
                NSLog(
                    "Persistent ModelContainer load failed on simulator. Falling back to in-memory: \(String(describing: error))"
                )
                do {
                    modelContainer = try Self.makeContainer(isStoredInMemoryOnly: true)
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

    private static func makeContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            cloudKitDatabase: .none
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
