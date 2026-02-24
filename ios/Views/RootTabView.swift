import SwiftUI

struct RootTabView: View {
    @State private var selection: RootTab = .home
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                HomeNavigationContainer()
                    .tag(RootTab.home)
                TagListView()
                    .tag(RootTab.tags)
                AnalyticsNavigationContainer()
                    .tag(RootTab.analytics)
                NavigationStack {
                    SettingsView()
                }
                .tag(RootTab.settings)
            }
            .toolbar(.hidden, for: .tabBar)

            HomeTabBarView(selection: $selection)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: selection) { oldValue, newValue in
            guard oldValue == .home, newValue != .home else { return }
            guard router.hasUnsavedEpisodeDetailChanges else { return }
            selection = oldValue
            router.requestRootTabSwitch(newValue)
        }
        .onChange(of: router.committedRootTabSwitch) { _, destination in
            guard let destination else { return }
            router.hasUnsavedEpisodeDetailChanges = false
            router.path.removeAll()
            selection = destination
            router.consumeCommittedRootTabSwitch()
        }
    }
}

private struct HomeNavigationContainer: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var store: EpisodeStore

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .newEpisode:
                        NewEpisodeView()
                            .environmentObject(store)
                    case .episodeDetail(let id):
                        EpisodeDetailContainer(episodeId: id)
                            .environmentObject(store)
                    }
                }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct AnalyticsNavigationContainer: View {
    var body: some View {
        NavigationStack {
            AnalyticsView()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
            .environmentObject(EpisodeStore())
            .environmentObject(AppRouter())
    }
}
