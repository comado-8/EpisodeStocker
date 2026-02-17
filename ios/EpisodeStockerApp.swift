import SwiftData
import SwiftUI

@main
struct EpisodeStockerApp: App {
    @StateObject private var store = EpisodeStore()
    @StateObject private var router = AppRouter()
    private let modelContainer: ModelContainer

    init() {
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: isRunningTests,
            cloudKitDatabase: .none
        )
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
            RootTabContainer()
                .environmentObject(store)
                .environmentObject(router)
                .modelContainer(modelContainer)
        }
    }
}

private struct RootTabContainer: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        RootTabView()
            .task { SeedData.seedIfNeeded(context: modelContext) }
    }
}
