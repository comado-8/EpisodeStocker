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

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                HomeNavigationContainer()
                    .tag(RootTab.home)
                TagListView()
                    .tag(RootTab.tags)
                AnalyticsNavigationContainer()
                    .tag(RootTab.analytics)
                SettingsView()
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
            guard oldValue == .home, newValue != .home else { return }
            guard router.hasUnsavedHomeStackChanges else { return }
            withTransaction(Transaction(animation: nil)) {
                selection = oldValue
            }
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
        .onChange(of: router.paywallTrigger) { _, trigger in
            guard trigger != nil else { return }
            openSubscriptionScreen()
        }
        #if canImport(RevenueCatUI)
        .sheet(isPresented: $showsRevenueCatPaywall) {
            RevenueCatFeatureGatePaywallContainer()
                .onDisappear {
                    Task { await premiumAccess.refresh(forceRefresh: true) }
                }
        }
        #endif
    }

    private func handleTabTap(_ tab: RootTab) {
        if tab == selection {
            handleReselectedTab(tab)
            return
        }
        clearReselectionArm()
        selection = tab
    }

    private func openSubscriptionScreen() {
        router.dismissPaywall()
        if Self.shouldForceRevenueCatFallback {
            openSubscriptionFallbackSettings()
            return
        }
        #if canImport(RevenueCatUI)
        showsRevenueCatPaywall = true
        #else
        openSubscriptionFallbackSettings()
        #endif
    }

    private func openSubscriptionFallbackSettings() {
        router.requestSettingsDeepLink(.subscription)
        if router.hasUnsavedHomeStackChanges {
            router.requestRootTabSwitch(.settings)
            return
        }
        clearReselectionArm()
        router.path.removeAll()
        selection = .settings
    }

    // For manual QA, set FORCE_RC_FALLBACK=1 to force settings fallback.
    private static let shouldForceRevenueCatFallback: Bool = {
        #if DEBUG
        let processInfo = ProcessInfo.processInfo

        if let rawFlag = processInfo.environment["FORCE_RC_FALLBACK"],
           let parsed = EnvironmentHelpers.parseBoolean(rawFlag)
        {
            return parsed
        }

        let arguments = processInfo.arguments
        if let argumentValue = parseFallbackValue(from: arguments) {
            return argumentValue
        }
        #endif
        return false
    }()

    private static func parseFallbackValue(from arguments: [String]) -> Bool? {
        if arguments.contains("-FORCE_RC_FALLBACK") {
            return true
        }
        if let pairArgument = arguments.first(where: { $0.hasPrefix("FORCE_RC_FALLBACK=") }) {
            let rawValue = String(pairArgument.dropFirst("FORCE_RC_FALLBACK=".count))
            return EnvironmentHelpers.parseBoolean(rawValue)
        }
        if let index = arguments.firstIndex(of: "-FORCE_RC_FALLBACK_VALUE"),
           arguments.indices.contains(index + 1)
        {
            return EnvironmentHelpers.parseBoolean(arguments[index + 1])
        }
        return nil
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
        case .settings:
            return router.hasSettingsDetailPath
        case .analytics:
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
        case .settings:
            router.requestSettingsRootReset()
        case .analytics:
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
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var premiumAccess: PremiumAccessViewModel

    private var isAnalyticsLocked: Bool {
        premiumAccess.hasLoadedStatus && !premiumAccess.hasAccess(to: .analyticsTab)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnalyticsView()
                    .blur(radius: isAnalyticsLocked ? 1.4 : 0)
                    .allowsHitTesting(!isAnalyticsLocked)

                if isAnalyticsLocked {
                    AnalyticsLockedOverlay {
                        router.presentPaywall(.analyticsTab)
                    }
                }
            }
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
            .environmentObject(AppPreferencesStore())
    }
}

private struct AnalyticsLockedOverlay: View {
    let onUpgrade: () -> Void
    private enum Style {
        static let cardCornerRadius: CGFloat = 16
        static let buttonHeight: CGFloat = 52
        static let buttonHorizontalInset: CGFloat = 10
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("分析はProで利用できます")
                .font(AppTypography.sectionTitle)
                .foregroundColor(HomeStyle.textPrimary)
            Text("履歴の傾向分析・掘り起こし候補・タグ分析を使うには、Proプランへアップグレードしてください。")
                .font(AppTypography.subtext)
                .foregroundColor(HomeStyle.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                onUpgrade()
            } label: {
                Text("Proで分析を使う")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: Style.buttonHeight)
                    .background(HomeStyle.fabRed)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Style.buttonHorizontalInset)
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: Style.cardCornerRadius, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Style.cardCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 20)
    }
}
