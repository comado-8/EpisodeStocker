import SwiftUI

@main
struct EpisodeStockerApp: App {
    @StateObject private var store = EpisodeStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
        }
    }
}
