import SwiftUI
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

struct RootTabView: View {
    @State private var selection: RootTab = .home
    @State private var lastReselectedTab: RootTab?
    @State private var lastReselectedAt: Date = .distantPast
    @State private var showsRevenueCatPaywall = false
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var premiumAccess: PremiumAccessViewModel

    private var paywallTriggerBinding: Binding<PaywallTrigger?> {
        Binding(
            get: { router.paywallTrigger },
            set: { _ in router.dismissPaywall() }
        )
    }

    private var shouldBlockAnalyticsTab: Bool {
        isAnalyticsPaywallEnabled && !premiumAccess.hasAccess(to: .analyticsTab)
    }

    private var isAnalyticsPaywallEnabled: Bool {
        // TODO(TAX-COMPLIANCE): 税務情報フォーム対応後にこのDEBUGバイパスを削除する。
        // 一時対応: 税務情報フォーム対応待ちのため、Debugのみ分析タブ課金ゲートを無効化する。
        // 課金テスト再開時は、このフラグを削除するか DEBUG でも true を返して復帰する。
        #if DEBUG
        return false
        #else
        return true
        #endif
    }

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

            HomeTabBarView(
                selection: $selection,
                onTabTap: handleTabTap,
                showsAnalyticsLock: !premiumAccess.hasAccess(to: .analyticsTab)
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: selection) { oldValue, newValue in
            if newValue == .analytics,
               shouldBlockAnalyticsTab
            {
                withTransaction(Transaction(animation: nil)) {
                    selection = oldValue
                }
                router.presentPaywall(.analyticsTab)
                return
            }
            guard oldValue == .home, newValue != .home else { return }
            guard router.hasUnsavedHomeStackChanges else { return }
            withTransaction(Transaction(animation: nil)) {
                selection = oldValue
            }
            router.requestRootTabSwitch(newValue)
        }
        .onChange(of: router.committedRootTabSwitch) { _, destination in
            guard let destination else { return }
            if destination == .analytics,
               shouldBlockAnalyticsTab
            {
                router.presentPaywall(.analyticsTab)
                router.consumeCommittedRootTabSwitch()
                return
            }
            clearReselectionArm()
            router.hasUnsavedEpisodeDetailChanges = false
            router.hasUnsavedNewEpisodeChanges = false
            router.path.removeAll()
            selection = destination
            router.consumeCommittedRootTabSwitch()
        }
        .sheet(item: paywallTriggerBinding) { trigger in
            PremiumPaywallSheet(
                trigger: trigger,
                onOpenSubscription: openSubscriptionScreen,
                onClose: router.dismissPaywall
            )
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
        }
        #if canImport(RevenueCatUI)
        .sheet(isPresented: $showsRevenueCatPaywall) {
            RevenueCatFeatureGatePaywallContainer()
                .onDisappear {
                    Task { await premiumAccess.refresh() }
                }
        }
        #endif
    }

    private func handleTabTap(_ tab: RootTab) {
        if tab == .analytics,
           shouldBlockAnalyticsTab
        {
            router.presentPaywall(.analyticsTab)
            return
        }
        if tab == selection {
            handleReselectedTab(tab)
            return
        }
        clearReselectionArm()
        selection = tab
    }

    private func openSubscriptionScreen() {
        #if canImport(RevenueCatUI)
        router.dismissPaywall()
        showsRevenueCatPaywall = true
        #else
        router.dismissPaywall()
        if router.hasUnsavedHomeStackChanges {
            router.requestRootTabSwitch(.settings)
            return
        }
        clearReselectionArm()
        router.path.removeAll()
        selection = .settings
        #endif
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

#if canImport(RevenueCatUI)
private struct RevenueCatFeatureGatePaywallContainer: View {
    var body: some View {
        PaywallView(displayCloseButton: true)
    }
}
#endif

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
    @EnvironmentObject private var store: EpisodeStore

    var body: some View {
        NavigationStack {
            AnalyticsView()
                .navigationDestination(for: UUID.self) { episodeID in
                    EpisodeDetailContainer(episodeId: episodeID)
                        .environmentObject(store)
                }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
            .environmentObject(EpisodeStore())
            .environmentObject(AppRouter())
            .environmentObject(PremiumAccessViewModel())
    }
}

private struct PremiumPaywallSheet: View {
    let trigger: PaywallTrigger
    let onOpenSubscription: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Premium")
                .font(AppTypography.sectionTitle)
                .foregroundColor(HomeStyle.fabRed)
            Text(trigger.title)
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(HomeStyle.textPrimary)
            Text(trigger.message)
                .font(AppTypography.body)
                .foregroundColor(HomeStyle.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                onOpenSubscription()
            } label: {
                Text("サブスクリプションを見る")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(HomeStyle.fabRed)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                onClose()
            } label: {
                Text("閉じる")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(HomeStyle.fabRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(HomeStyle.fabRed.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(HomeStyle.background.ignoresSafeArea())
    }
}
