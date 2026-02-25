import SwiftUI

struct RootTabView: View {
    @State private var selection: RootTab = .home
    @State private var lastReselectedTab: RootTab?
    @State private var lastReselectedAt: Date = .distantPast
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

            HomeTabBarView(selection: $selection, onTabTap: handleTabTap)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: selection) { oldValue, newValue in
            guard oldValue == .home, newValue != .home else { return }
            guard router.hasUnsavedHomeStackChanges else { return }
            selection = oldValue
            router.requestRootTabSwitch(newValue)
        }
        .onChange(of: router.committedRootTabSwitch) { _, destination in
            guard let destination else { return }
            clearReselectionArm()
            router.hasUnsavedEpisodeDetailChanges = false
            router.hasUnsavedNewEpisodeChanges = false
            router.path.removeAll()
            selection = destination
            router.consumeCommittedRootTabSwitch()
        }
    }

    private func handleTabTap(_ tab: RootTab) {
        if tab == selection {
            handleReselectedTab(tab)
            return
        }
        clearReselectionArm()
        selection = tab
    }

    private func handleReselectedTab(_ tab: RootTab) {
        guard canReturnToTabRoot(for: tab) else { return }
        guard isReselectionConfirmed(for: tab) else {
            armReselection(for: tab)
            return
        }
        clearReselectionArm()
        DispatchQueue.main.asyncAfter(deadline: .now() + RootTabReselectStyle.returnDelay) {
            performReturnToTabRoot(tab)
        }
    }

    private func canReturnToTabRoot(for tab: RootTab) -> Bool {
        switch tab {
        case .home:
            return !router.path.isEmpty
        case .tags:
            return router.hasTagDetailPath
        case .analytics, .settings:
            return false
        }
    }

    private func performReturnToTabRoot(_ tab: RootTab) {
        guard selection == tab else { return }
        switch tab {
        case .home:
            if router.hasUnsavedHomeStackChanges {
                router.requestRootTabSwitch(.home)
                return
            }
            router.path.removeAll()
        case .tags:
            router.requestTagRootReset()
        case .analytics, .settings:
            break
        }
    }

    private func armReselection(for tab: RootTab) {
        lastReselectedTab = tab
        lastReselectedAt = Date()
    }

    private func isReselectionConfirmed(for tab: RootTab) -> Bool {
        guard lastReselectedTab == tab else { return false }
        return Date().timeIntervalSince(lastReselectedAt) <= RootTabReselectStyle.doubleTapWindow
    }

    private func clearReselectionArm() {
        lastReselectedTab = nil
        lastReselectedAt = .distantPast
    }
}

private enum RootTabReselectStyle {
    static let doubleTapWindow: TimeInterval = 0.65
    static let returnDelay: TimeInterval = 0.12
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
