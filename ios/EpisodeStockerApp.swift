import SwiftData
import SwiftUI

@main
struct EpisodeStockerApp: App {
    @StateObject private var store = EpisodeStore()
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootTabContainer()
                .environmentObject(store)
                .environmentObject(router)
                .modelContainer(
                    for: [
                        Episode.self,
                        UnlockLog.self,
                        Tag.self,
                        Person.self,
                        Project.self,
                        Emotion.self,
                        Place.self
                    ]
                )
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
