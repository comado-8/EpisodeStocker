import SwiftData
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

struct SettingsView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var navigationPath: [SettingsDestination] = []
    private let items: [SettingsItemData] = [
        .init(title: "サブスクリプション", detail: "プラン/更新日/試用残日数", systemImage: "creditcard", destination: .subscription),
        .init(title: "同期・バックアップ", detail: "クラウド同期の状態管理", systemImage: "icloud", destination: .backup),
        .init(title: "セキュリティ", detail: "パスコード/生体認証", systemImage: "lock", destination: .security),
        .init(title: "表示", detail: "テーマカラー", systemImage: "paintpalette", destination: .display),
        .init(title: "サポート", detail: "メールで問い合わせ", systemImage: "envelope", destination: .support),
        .init(title: "利用規約とプライバシーポリシー", detail: "利用に関する重要事項", systemImage: "doc.text", destination: .legal)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { proxy in
                let contentWidth = HomeStyle.primaryScreenContentWidth(for: proxy.size.width)
                let bottomInset = baseSafeAreaBottom()
                let topPadding = max(0, SettingsStyle.figmaTopInset - proxy.safeAreaInsets.top)

                ZStack {
                    HomeStyle.screenBackground.ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: SettingsStyle.sectionSpacing) {
                            SettingsHeaderView()
                                .frame(width: contentWidth, alignment: .leading)

                            Rectangle()
                                .fill(HomeStyle.outline)
                                .frame(width: contentWidth, height: HomeStyle.dividerHeight)

                            VStack(spacing: SettingsStyle.cardSpacing) {
                                ForEach(items) { item in
                                    NavigationLink(value: item.destination) {
                                        SettingsCardView(item: item, width: contentWidth)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(width: contentWidth, alignment: .center)
                        }
                        .padding(.top, topPadding)
                        .padding(.bottom, HomeStyle.tabBarHeight + 16 + bottomInset)
                        .frame(maxWidth: .infinity)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
            .navigationDestination(for: SettingsDestination.self) { destination in
                SettingsDestinationView(destination: destination)
            }
        }
        .onAppear {
            router.hasSettingsDetailPath = !navigationPath.isEmpty
            applyDeepLinkIfNeeded()
        }
        .onChange(of: navigationPath) { _, newValue in
            router.hasSettingsDetailPath = !newValue.isEmpty
        }
        .onChange(of: router.settingsRootResetSignal) { _, _ in
            guard !navigationPath.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                navigationPath.removeAll()
            }
        }
        .onChange(of: router.settingsDeepLink) { _, _ in
            applyDeepLinkIfNeeded()
        }
    }

    private func applyDeepLinkIfNeeded() {
        guard let deepLink = router.settingsDeepLink else { return }
        switch deepLink {
        case .subscription:
            navigationPath = [.subscription]
        }
        router.consumeSettingsDeepLink()
    }
}

private struct SettingsHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("設定")
                .font(SettingsStyle.headerFont)
                .foregroundColor(SettingsStyle.headerText)
            Text("アプリの各種設定をまとめて確認できます。")
                .font(SettingsStyle.subheaderFont)
                .foregroundColor(SettingsStyle.subheaderText)
        }
    }
}

private struct SettingsCardView: View {
    let item: SettingsItemData
    let width: CGFloat

    var body: some View {
        HStack(spacing: SettingsStyle.rowSpacing) {
            ZStack {
                Circle()
                    .fill(SettingsStyle.iconFill)
                    .frame(width: SettingsStyle.iconSize, height: SettingsStyle.iconSize)
                    .overlay(
                        Circle()
                            .stroke(SettingsStyle.iconBorder, lineWidth: 1)
                    )
                Image(systemName: item.systemImage)
                    .font(.system(size: SettingsStyle.iconGlyphSize, weight: .semibold))
                    .foregroundColor(SettingsStyle.iconTint)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(SettingsStyle.rowTitleFont)
                    .foregroundColor(SettingsStyle.rowTitleText)

                Text(item.detail)
                    .font(SettingsStyle.rowBodyFont)
                    .foregroundColor(SettingsStyle.rowBodyText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: SettingsStyle.chevronSize, weight: .semibold))
                .foregroundColor(SettingsStyle.chevronTint)
        }
        .padding(.horizontal, SettingsStyle.rowHorizontalPadding)
        .padding(.vertical, SettingsStyle.rowVerticalPadding)
        .frame(width: width, alignment: .center)
        .background(SettingsStyle.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: SettingsStyle.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SettingsStyle.cardCornerRadius, style: .continuous)
                .stroke(SettingsStyle.cardBorder, lineWidth: SettingsStyle.cardBorderWidth)
        )
        .shadow(
            color: SettingsStyle.cardShadowPrimary,
            radius: SettingsStyle.cardShadowPrimaryRadius,
            x: 0,
            y: SettingsStyle.cardShadowPrimaryY
        )
        .shadow(
            color: SettingsStyle.cardShadowSecondary,
            radius: SettingsStyle.cardShadowSecondaryRadius,
            x: 0,
            y: SettingsStyle.cardShadowSecondaryY
        )
    }
}

private struct SettingsItemData: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let destination: SettingsDestination
}

private enum SettingsDestination: Hashable {
    case subscription
    case backup
    case security
    case display
    case support
    case legal
}

private struct SettingsDestinationView: View {
    let destination: SettingsDestination
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        switch destination {
        case .subscription:
            SubscriptionSettingsView()
        case .backup:
            BackupSettingsDestinationView(modelContext: modelContext)
        case .security:
            SecuritySettingsView()
        case .display:
            DisplaySettingsView()
        case .support:
            SupportSettingsView()
        case .legal:
            LegalSettingsView()
        }
    }
}

private enum SettingsStyle {
    static let figmaTopInset: CGFloat = 59
    static let sectionSpacing: CGFloat = 16
    static let cardSpacing: CGFloat = 12

    static let rowSpacing: CGFloat = 12
    static let rowHorizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 14

    static let cardCornerRadius: CGFloat = 12
    static let cardBorderWidth: CGFloat = 0.66

    static let iconSize: CGFloat = 40
    static let iconGlyphSize: CGFloat = 18
    static let chevronSize: CGFloat = 12

    static let headerFont = AppTypography.screenTitle
    static let subheaderFont = AppTypography.subtext
    static let rowTitleFont = AppTypography.bodyEmphasis
    static let rowBodyFont = AppTypography.subtext

    static let headerText = HomeStyle.textPrimary
    static let subheaderText = HomeStyle.textSecondary
    static let rowTitleText = HomeStyle.textPrimary
    static let rowBodyText = HomeStyle.textSecondary

    static let cardFill = Color.white
    static let cardBorder = Color(hex: "E5E7EB")
    static let iconFill = Color(hex: "F3F4F6")
    static let iconTint = HomeStyle.fabRed
    static let iconBorder = HomeStyle.fabRed.opacity(0.25)
    static let chevronTint = Color(hex: "9CA3AF")

    static let cardShadowPrimary = Color.black.opacity(0.12)
    static let cardShadowPrimaryRadius: CGFloat = 2
    static let cardShadowPrimaryY: CGFloat = 1
    static let cardShadowSecondary = Color.black.opacity(0.06)
    static let cardShadowSecondaryRadius: CGFloat = 6
    static let cardShadowSecondaryY: CGFloat = 3
}

private struct SettingsDetailHeader: View {
    let title: String
    let subtitle: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SettingsDetailStyle.headerText)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    .padding(8)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SettingsDetailStyle.headerFont)
                    .foregroundColor(SettingsDetailStyle.headerText)
                Text(subtitle)
                    .font(SettingsDetailStyle.subheaderFont)
                    .foregroundColor(SettingsDetailStyle.subheaderText)
            }

            Spacer(minLength: 0)
        }
        .frame(height: SettingsDetailStyle.headerHeight)
    }
}

private struct SettingsSectionCard<Content: View, HeaderAccessory: View>: View {
    let title: String
    let subtitle: String
    let content: Content
    let headerAccessory: HeaderAccessory

    init(
        title: String,
        subtitle: String,
        @ViewBuilder headerAccessory: () -> HeaderAccessory = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.headerAccessory = headerAccessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(SettingsDetailStyle.sectionTitleFont)
                        .foregroundColor(SettingsDetailStyle.sectionTitleText)
                    Text(subtitle)
                        .font(SettingsDetailStyle.sectionSubtitleFont)
                        .foregroundColor(SettingsDetailStyle.sectionSubtitleText)
                }
                Spacer(minLength: 0)
                headerAccessory
            }
            content
        }
        .padding(16)
        .background(SettingsDetailStyle.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: SettingsDetailStyle.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SettingsDetailStyle.cardCornerRadius, style: .continuous)
                .stroke(SettingsDetailStyle.cardBorder, lineWidth: SettingsDetailStyle.cardBorderWidth)
        )
        .shadow(
            color: SettingsDetailStyle.cardShadowPrimary,
            radius: SettingsDetailStyle.cardShadowPrimaryRadius,
            x: 0,
            y: SettingsDetailStyle.cardShadowPrimaryY
        )
        .shadow(
            color: SettingsDetailStyle.cardShadowSecondary,
            radius: SettingsDetailStyle.cardShadowSecondaryRadius,
            x: 0,
            y: SettingsDetailStyle.cardShadowSecondaryY
        )
    }
}

private struct SettingsKeyValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(SettingsDetailStyle.rowTitleFont)
                .foregroundColor(SettingsDetailStyle.rowTitleText)
            Spacer(minLength: 0)
            Text(value)
                .font(SettingsDetailStyle.rowValueFont)
                .foregroundColor(SettingsDetailStyle.rowValueText)
        }
    }
}

private struct SettingsActionButton: View {
    let title: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(SettingsDetailStyle.actionFont)
            .foregroundColor(isPrimary ? SettingsDetailStyle.actionPrimaryText : SettingsDetailStyle.actionSecondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: SettingsDetailStyle.actionHeight)
            .background(
                RoundedRectangle(cornerRadius: SettingsDetailStyle.actionCornerRadius, style: .continuous)
                    .fill(isPrimary ? SettingsDetailStyle.actionPrimaryFill : SettingsDetailStyle.actionSecondaryFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SettingsDetailStyle.actionCornerRadius, style: .continuous)
                    .stroke(SettingsDetailStyle.actionSecondaryBorder, lineWidth: isPrimary ? 0 : 1)
            )
    }
}

private struct ProFeatureBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
            Text("Pro")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(HomeStyle.fabRed)
        .clipShape(Capsule())
        .accessibilityLabel("Pro機能")
    }
}

@MainActor
private struct SubscriptionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var premiumAccess: PremiumAccessViewModel
    @StateObject private var viewModel: SubscriptionSettingsViewModel
    @State private var showsCustomerCenter = false
    @State private var manageSubscriptionsErrorMessage: String?
    @State private var restoreSupportMessage: String?
    @State private var activePurchaseProductID: String?
    private static let loadingPriceText = "価格情報を取得中..."
    private static let termsURLString = "https://episodestocker.com/terms"
    private static let privacyURLString = "https://episodestocker.com/privacy"
    private static var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    private static let proFeatures: [String] = [
        "高度分析ダッシュボード",
        "エピソード登録件数無制限",
        "詳細履歴検索",
        "エピソードエクスポート",
        "クラウド同期"
    ]

    init(viewModel: SubscriptionSettingsViewModel? = nil) {
        _viewModel = StateObject(
            wrappedValue: viewModel ?? SubscriptionSettingsViewModel(service: SubscriptionServiceFactory.makeService())
        )
    }

    private var planLabel: String {
        planLabel(for: viewModel.status.plan)
    }

    private func planLabel(for plan: SubscriptionStatus.Plan) -> String {
        switch plan {
        case .free:
            return "Free"
        case .monthly:
            return "Pro Monthly"
        case .yearly:
            return "Pro Yearly"
        }
    }

    private var pendingPlanChangeText: String? {
        guard let nextPlan = viewModel.status.nextPlan else { return nil }
        guard nextPlan != viewModel.status.plan else { return nil }

        let nextPlanLabel = planLabel(for: nextPlan)
        if let effectiveDate = viewModel.status.nextPlanEffectiveDate {
            return "次回更新時（\(Self.dateFormatter.string(from: effectiveDate))）に\(nextPlanLabel)へ切り替わります。"
        }
        return "次回更新時に\(nextPlanLabel)へ切り替わります。"
    }

    private var isCancellationScheduled: Bool {
        guard viewModel.status.plan != .free else { return false }
        guard viewModel.status.nextPlan == nil else { return false }
        return viewModel.status.willAutoRenew == false
    }

    private var renewalDateLabel: String {
        isCancellationScheduled ? "有効期限" : "更新日"
    }

    private var cancellationNoticeText: String? {
        guard isCancellationScheduled else { return nil }
        if expiryDateText != "-" {
            return "解約済みです。\(expiryDateText) まで現在のプランを利用できます。"
        }
        return "解約済みです。次回更新はありません。"
    }

    private var expiryDateText: String {
        guard let expiryDate = viewModel.status.expiryDate else {
            return "-"
        }
        return Self.dateFormatter.string(from: expiryDate)
    }

    private var trialText: String? {
        guard viewModel.trialRemainingDays > 0 else {
            return nil
        }
        return "\(viewModel.trialRemainingDays)日"
    }

    private var monthlyProduct: SubscriptionProduct? {
        viewModel.products.first(where: { $0.plan == .monthly })
    }

    private var yearlyProduct: SubscriptionProduct? {
        viewModel.products.first(where: { $0.plan == .yearly })
    }

    private func isCurrentPlan(_ plan: SubscriptionStatus.Plan) -> Bool {
        viewModel.status.plan == plan
    }

    private var monthlyPriceText: String {
        monthlyProduct?.displayPrice ?? Self.loadingPriceText
    }

    private var yearlyPriceText: String {
        yearlyProduct?.displayPrice ?? Self.loadingPriceText
    }

    private var yearlyMonthlyEquivalentText: String? {
        yearlyProduct?.monthlyEquivalentText
    }

    private var isPurchaseInteractionDisabled: Bool {
        viewModel.isLoading || activePurchaseProductID != nil
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    private func handlePurchaseTap(_ product: SubscriptionProduct) {
        guard activePurchaseProductID == nil && !viewModel.isLoading else { return }

        activePurchaseProductID = product.id
        Task {
            await viewModel.purchase(productID: product.id)
            await viewModel.refreshProducts()
            await premiumAccess.refresh(forceRefresh: true)
            await MainActor.run {
                activePurchaseProductID = nil
            }
        }
    }

    private func handleRestoreTap() {
        restoreSupportMessage = nil

        #if canImport(RevenueCatUI)
        if RevenueCatConfig.hasPublicAPIKey {
            showsCustomerCenter = true
            return
        }

        restoreSupportMessage = "Customer Centerを開けないため、アプリ内で購入を復元します。"
        #endif

        Task {
            await viewModel.restorePurchases()
            await viewModel.refreshStatus(forceRefresh: true)
            await viewModel.refreshProducts()
            await premiumAccess.refresh(forceRefresh: true)
            if viewModel.errorMessage == nil {
                restoreSupportMessage = nil
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = HomeStyle.primaryScreenContentWidth(for: proxy.size.width)
            let bottomInset = baseSafeAreaBottom()
            let topPadding = max(0, SettingsStyle.figmaTopInset - proxy.safeAreaInsets.top)

            ZStack(alignment: .top) {
                HomeStyle.screenBackground.ignoresSafeArea()

                VStack(spacing: SettingsDetailStyle.sectionSpacing) {
                    VStack(spacing: SettingsDetailStyle.sectionSpacing) {
                        SettingsDetailHeader(
                            title: "サブスクリプション",
                            subtitle: "プラン情報と更新日を確認"
                        )
                        .frame(width: contentWidth, alignment: .leading)

                        Rectangle()
                            .fill(HomeStyle.outline)
                            .frame(width: contentWidth, height: HomeStyle.dividerHeight)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, topPadding)
                    .background(HomeStyle.screenBackground)
                    .zIndex(1)

                    ScrollView {
                        VStack(spacing: SettingsDetailStyle.sectionSpacing) {
                            subscriptionSections
                        }
                        .frame(width: contentWidth)
                        .padding(.bottom, HomeStyle.tabBarHeight + 12 + bottomInset)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .scrollClipDisabled()
                    .scrollBounceBehavior(.basedOnSize)
                    .zIndex(0)
                }
                .frame(maxWidth: .infinity, alignment: .top)

                Rectangle()
                    .fill(HomeStyle.screenBackground)
                    .frame(height: proxy.safeAreaInsets.top)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    .zIndex(2)
            }
            .toolbar(.hidden, for: .navigationBar)
            .edgeSwipeBack {
                dismiss()
            }
        }
        .task {
            await viewModel.load()
            await premiumAccess.refresh(forceRefresh: true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await viewModel.refreshStatus(forceRefresh: true)
                await viewModel.refreshProducts()
                await premiumAccess.refresh(forceRefresh: true)
            }
        }
        #if canImport(RevenueCatUI)
        .sheet(isPresented: $showsCustomerCenter, onDismiss: {
            Task {
                await viewModel.refreshStatus(forceRefresh: true)
                await viewModel.refreshProducts()
                await premiumAccess.refresh(forceRefresh: true)
            }
        }) {
            RevenueCatCustomerCenterContainer()
        }
        #endif
    }

    @ViewBuilder
    private var subscriptionSections: some View {
        SubscriptionPlainSection(title: "現在のプラン", subtitle: "") {
            Text(planLabel)
                .font(SettingsDetailStyle.rowTitleFont)
                .foregroundColor(SettingsDetailStyle.rowTitleText)
            if let trialText {
                Text("試用残日数: \(trialText)")
                    .font(SettingsDetailStyle.rowMetaFont)
                    .foregroundColor(SettingsDetailStyle.rowMetaText)
            } else if expiryDateText != "-" {
                Text("\(renewalDateLabel): \(expiryDateText)")
                    .font(SettingsDetailStyle.rowMetaFont)
                    .foregroundColor(SettingsDetailStyle.rowMetaText)
            }
            if let pendingPlanChangeText {
                Text(pendingPlanChangeText)
                    .font(SettingsDetailStyle.rowMetaFont)
                    .foregroundColor(HomeStyle.fabRed)
            } else if let cancellationNoticeText {
                Text(cancellationNoticeText)
                    .font(SettingsDetailStyle.rowMetaFont)
                    .foregroundColor(HomeStyle.fabRed)
            }
        }

        SubscriptionPlainSection(title: "Proでできること", subtitle: "Proプランで利用できる機能") {
            SubscriptionBenefitsBlock(features: Self.proFeatures)
        }

        SubscriptionPlainSection(title: "プランを選択", subtitle: "継続利用の場合、年額プランがお得です") {
            VStack(spacing: 12) {
                SubscriptionPlanCard(
                    title: "Pro Yearly",
                    badgeText: "おすすめ",
                    isRecommended: true,
                    priceText: yearlyPriceText,
                    priceSuffix: "年",
                    secondaryPriceText: yearlyMonthlyEquivalentText,
                    isPrimaryAction: true,
                    isActionInProgress: activePurchaseProductID == yearlyProduct?.id,
                    isInteractionDisabled: isPurchaseInteractionDisabled,
                    isPurchaseAvailable: yearlyProduct != nil,
                    isSelectable: !isCurrentPlan(.yearly)
                ) {
                    guard let product = yearlyProduct else { return }
                    handlePurchaseTap(product)
                }
                SubscriptionPlanCard(
                    title: "Pro Monthly",
                    badgeText: nil,
                    isRecommended: false,
                    priceText: monthlyPriceText,
                    priceSuffix: "月",
                    secondaryPriceText: nil,
                    isPrimaryAction: false,
                    isActionInProgress: activePurchaseProductID == monthlyProduct?.id,
                    isInteractionDisabled: isPurchaseInteractionDisabled,
                    isPurchaseAvailable: monthlyProduct != nil,
                    isSelectable: !isCurrentPlan(.monthly)
                ) {
                    guard let product = monthlyProduct else { return }
                    handlePurchaseTap(product)
                }
            }
        }

        SubscriptionPlainSection(title: "サブスクリプションについて", subtitle: "") {
            VStack(alignment: .leading, spacing: 8) {
                Text("・サブスクリプションは期間終了の24時間前までにキャンセルされない限り自動更新されます。")
                    .font(SettingsDetailStyle.rowMetaFont)
                    .foregroundColor(SettingsDetailStyle.rowMetaText)
                Text("・サブスクリプションは以下から管理・解約できます。")
                    .font(SettingsDetailStyle.rowMetaFont)
                    .foregroundColor(SettingsDetailStyle.rowMetaText)
                SettingsLinkRow(title: "設定＞Apple Account＞サブスクリプション") {
                    openManageSubscriptions()
                }
                if let manageSubscriptionsErrorMessage {
                    Text(manageSubscriptionsErrorMessage)
                        .font(SettingsDetailStyle.rowMetaFont)
                        .foregroundColor(.red)
                }
            }
        }

        SubscriptionPlainSection(title: "購入サポート", subtitle: "復元や購読管理の操作", showsDivider: false) {
            VStack(alignment: .leading, spacing: 12) {
                SubscriptionPillButton(title: "購入を復元", isPrimary: false) {
                    handleRestoreTap()
                }
                .disabled(viewModel.isLoading)

                if let restoreSupportMessage {
                    Text(restoreSupportMessage)
                        .font(SettingsDetailStyle.rowMetaFont)
                        .foregroundColor(HomeStyle.fabRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Rectangle()
                    .fill(HomeStyle.outline)
                    .frame(height: HomeStyle.dividerHeight)
                    .padding(.top, 2)

                SettingsLinkRow(title: "利用規約") {
                    guard let url = URL(string: Self.termsURLString) else { return }
                    openURL(url)
                }
                SettingsLinkRow(title: "プライバシーポリシー") {
                    guard let url = URL(string: Self.privacyURLString) else { return }
                    openURL(url)
                }

                Text("© \(Self.currentYear) comado.studio All rights reserved.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(SettingsDetailStyle.rowMetaText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }

        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(SettingsDetailStyle.rowMetaFont)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func openManageSubscriptions() {
        Task { @MainActor in
            do {
                guard let scene = activeWindowScene else {
                    throw URLError(.badURL)
                }
                try await AppStore.showManageSubscriptions(in: scene)
                manageSubscriptionsErrorMessage = nil
            } catch {
                manageSubscriptionsErrorMessage = "サブスクリプション管理画面を開けませんでした。"
            }
        }
    }

    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
    }
}

private struct SubscriptionPlanCard: View {
    let title: String
    let badgeText: String?
    let isRecommended: Bool
    let priceText: String
    let priceSuffix: String
    let secondaryPriceText: String?
    let isPrimaryAction: Bool
    let isActionInProgress: Bool
    let isInteractionDisabled: Bool
    let isPurchaseAvailable: Bool
    let isSelectable: Bool
    let onTap: () -> Void
    private static let loadingPriceText = "価格情報を取得中..."

    private var displayedPrice: String {
        guard priceText != Self.loadingPriceText else { return Self.loadingPriceText }
        return "\(priceText) / \(priceSuffix)"
    }

    private var buttonTitle: String {
        isActionInProgress ? "処理中..." : "このプランを選択"
    }

    private var isDisabled: Bool {
        isInteractionDisabled || isActionInProgress || !isPurchaseAvailable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(SettingsDetailStyle.rowTitleFont)
                    .foregroundColor(SettingsDetailStyle.rowTitleText)
                if let badgeText {
                    Text(badgeText)
                        .font(SettingsDetailStyle.rowMetaFont)
                        .foregroundColor(Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(HomeStyle.fabRed)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 0)
            }

            Text(displayedPrice)
                .font(AppTypography.sectionTitle)
                .foregroundColor(SettingsDetailStyle.rowTitleText)

            if let secondaryPriceText {
                Text(secondaryPriceText)
                    .font(SettingsDetailStyle.rowMetaFont)
                    .foregroundColor(SettingsDetailStyle.rowMetaText)
            }

            if isSelectable {
                SubscriptionPillButton(title: buttonTitle, isPrimary: isPrimaryAction) {
                    onTap()
                }
                .disabled(isDisabled)
            }
        }
        .padding(14)
        .background(isRecommended ? HomeStyle.fabRed.opacity(0.08) : Color(hex: "FAFAFB"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isRecommended ? HomeStyle.fabRed.opacity(0.55) : HomeStyle.fabRed.opacity(0.75), lineWidth: isRecommended ? 1.2 : 1.1)
        )
        .shadow(
            color: isRecommended ? HomeStyle.fabRed.opacity(0.18) : Color.black.opacity(0.06),
            radius: isRecommended ? 10 : 4,
            x: 0,
            y: isRecommended ? 5 : 2
        )
    }
}

private struct SubscriptionPillButton: View {
    let title: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SettingsDetailStyle.actionFont)
                .foregroundColor(isPrimary ? SettingsDetailStyle.actionPrimaryText : SettingsDetailStyle.actionSecondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: SettingsDetailStyle.actionHeight)
                .background(
                    Capsule()
                        .fill(isPrimary ? SettingsDetailStyle.actionPrimaryFill : SettingsDetailStyle.actionSecondaryFill)
                )
                .overlay(
                    Capsule()
                        .stroke(SettingsDetailStyle.actionSecondaryBorder, lineWidth: isPrimary ? 0 : 1)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SubscriptionPlainSection<Content: View>: View {
    let title: String
    let subtitle: String
    let showsDivider: Bool
    let content: Content

    init(
        title: String,
        subtitle: String,
        showsDivider: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsDivider = showsDivider
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SettingsDetailStyle.sectionTitleFont)
                    .foregroundColor(SettingsDetailStyle.sectionTitleText)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(SettingsDetailStyle.sectionSubtitleFont)
                        .foregroundColor(SettingsDetailStyle.sectionSubtitleText)
                }
            }

            content

            if showsDivider {
                Rectangle()
                    .fill(HomeStyle.outline)
                    .frame(height: HomeStyle.dividerHeight)
                    .padding(.top, 2)
            }
        }
    }
}

private struct SubscriptionBenefitsBlock: View {
    let features: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HomeStyle.fabRed)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature)
                            .font(SettingsDetailStyle.rowTitleFont)
                            .foregroundColor(SettingsDetailStyle.rowTitleText)
                    }
                }
            }
        }
    }
}

@MainActor
private struct BackupSettingsDestinationView: View {
    @StateObject private var manualBackupViewModel: ManualBackupSettingsViewModel

    init(modelContext: ModelContext) {
        _manualBackupViewModel = StateObject(
            wrappedValue: ManualBackupSettingsViewModel(
                manualBackupService: EncryptedManualBackupService(modelContext: modelContext)
            )
        )
    }

    var body: some View {
        BackupSettingsView(manualBackupViewModel: manualBackupViewModel)
    }
}

@MainActor
private struct BackupSettingsView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: BackupSettingsViewModel
    @ObservedObject private var manualBackupViewModel: ManualBackupSettingsViewModel
    @State private var showsExportPassphraseSheet = false
    @State private var showsImportPassphraseSheet = false
    @State private var showsImportFileGuide = false
    @State private var showsFileImporter = false
    @State private var showsRestoreConfirmationSheet = false
    @State private var showsShareSheet = false
    @State private var showsAppleAccountSignInAlert = false
    @State private var shareItems: [Any] = []
    @State private var selectedImportURL: URL?
    private let subscriptionService: SubscriptionService

    private static var isBackupPaywallEnabled: Bool {
        if let rawFlag = ProcessInfo.processInfo.environment["ENABLE_BACKUP_PAYWALL"],
           let parsedFlag = EnvironmentHelpers.parseBoolean(rawFlag)
        {
            return parsedFlag
        }
        return true
    }

    init(
        viewModel: BackupSettingsViewModel? = nil,
        manualBackupViewModel: ManualBackupSettingsViewModel,
        subscriptionService: SubscriptionService = SubscriptionServiceFactory.makeService()
    ) {
        self.subscriptionService = subscriptionService
        _viewModel = StateObject(
            wrappedValue: viewModel ?? BackupSettingsViewModel(
                cloudBackupService: CloudKitBackupService(),
                isEntitlementCheckEnabled: Self.isBackupPaywallEnabled,
                minimumInitialLoadingVisibleDuration: .milliseconds(1200)
            )
        )
        self.manualBackupViewModel = manualBackupViewModel
    }

    private var backupBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isBackupEnabled },
            set: { setBackupEnabledWithPaywallGate($0) }
        )
    }

    private var lastBackupText: String {
        guard let lastBackupAt = viewModel.lastSyncAt else {
            return "未実行"
        }
        return Self.backupDateFormatter.string(from: lastBackupAt)
    }

    private var syncStateText: String {
        if viewModel.isInitialSubscriptionResolving {
            return "確認中"
        }
        guard viewModel.isBackupEnabled else {
            return "オフ"
        }
        if case .unavailable = viewModel.availability {
            return "利用不可"
        }
        return viewModel.isSyncing ? "同期中" : "待機中"
    }

    private var iCloudStatusText: String {
        switch viewModel.availability {
        case .available:
            return "利用可能"
        case .unavailable:
            return viewModel.needsAppleAccountSignIn ? "未サインイン" : "利用できません"
        }
    }

    private var iCloudStatusHelpText: String? {
        switch viewModel.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            if viewModel.needsAppleAccountSignIn {
                return "『設定』アプリのApple Accountからサインインしてください。"
            }
            return reason
        }
    }

    private var visibleErrorMessage: String? {
        guard let errorMessage = viewModel.errorMessage else { return nil }
        if case .unavailable(let reason) = viewModel.availability, reason == errorMessage {
            return nil
        }
        return errorMessage
    }

    private static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    private static let manualBackupContentType: UTType = {
        UTType(exportedAs: "com.episodestocker.manual-backup")
    }()

    private var manualLastExportText: String {
        guard let date = manualBackupViewModel.lastExportAt else {
            return "未実行"
        }
        return Self.backupDateFormatter.string(from: date)
    }

    private var manualLastRestoreText: String {
        guard let date = manualBackupViewModel.lastRestoreAt else {
            return "未実行"
        }
        return Self.backupDateFormatter.string(from: date)
    }

    private var isBackupLocked: Bool {
        Self.isBackupPaywallEnabled
            && !viewModel.isInitialSubscriptionResolving
            && !viewModel.hasBackupAccess
    }

    private var isSyncInteractionDisabled: Bool {
        viewModel.isSyncInteractionDisabled
    }

    private enum PremiumLockOverlayPosition {
        case center
        case bottom
    }

    private enum PremiumLockCTAStyle {
        static let height: CGFloat = 52
        static let horizontalInset: CGFloat = 16
        static let bottomReservedSpace: CGFloat = height + 14
    }

    var body: some View {
        SettingsDetailContainerView(
            title: "同期・バックアップ",
            subtitle: "クラウド同期の状態管理"
        ) {
            SettingsSectionCard(
                title: "クラウド同期",
                subtitle: "有効化と状態",
                headerAccessory: {
                    if isBackupLocked {
                        ProFeatureBadge()
                    }
                }
            ) {
                premiumLockedContent(
                    isLocked: isBackupLocked,
                    overlayPosition: .center,
                    ctaTitle: "Proでクラウド同期を使う"
                ) {
                    SettingsToggleRow(
                        title: "クラウド同期を有効にする",
                        isOn: backupBinding,
                        isDisabled: isSyncInteractionDisabled
                    )

                    if viewModel.isInitialSubscriptionResolving {
                        syncGuideMessage("サブスク状態を確認中です。確認が完了するまで同期操作は利用できません。")
                    }

                    SettingsKeyValueRow(title: "iCloudの状態", value: iCloudStatusText)
                    if let iCloudStatusHelpText {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(HomeStyle.fabRed)
                                .padding(.top, 1)
                            Text(iCloudStatusHelpText)
                                .font(SettingsDetailStyle.rowMetaFont)
                                .foregroundColor(SettingsDetailStyle.rowMetaText)
                        }
                        .padding(.top, 4)
                    }

                    SettingsKeyValueRow(title: "同期状態", value: syncStateText)

                    VStack(spacing: 10) {
                        SettingsKeyValueRow(title: "最終同期日時", value: lastBackupText)
                    }
                    .padding(.top, 4)

                    syncGuideMessage("別端末で初めて使う場合は、その端末でも『クラウド同期を有効にする』をオンにしてください。")
                    syncGuideMessage("同期反映まで1〜2分かかる場合があります。反映されない場合は恐れ入りますがアプリの再起動をお願いします。")

                    if let visibleErrorMessage {
                        Text(visibleErrorMessage)
                            .font(SettingsDetailStyle.rowMetaFont)
                            .foregroundColor(.red)
                            .padding(.top, 2)
                    }
                }
            }

            SettingsSectionCard(
                title: "手動バックアップ",
                subtitle: "ダウンロード/アップロード",
                headerAccessory: {
                    if isBackupLocked {
                        ProFeatureBadge()
                    }
                }
            ) {
                premiumLockedContent(
                    isLocked: isBackupLocked,
                    overlayPosition: .bottom,
                    ctaTitle: "Proでバックアップを使う"
                ) {
                    Text("通常はiCloudでのデータ同期の利用をおすすめします。手動バックアップは必要な場合にご利用ください。")
                        .font(SettingsDetailStyle.rowMetaFont)
                        .foregroundColor(SettingsDetailStyle.rowMetaText)

                    SettingsKeyValueRow(title: "最終ダウンロード日時", value: manualLastExportText)
                    SettingsKeyValueRow(title: "最終アップロード日時", value: manualLastRestoreText)

                    if !isBackupLocked {
                        VStack(spacing: 10) {
                            SettingsActionButton(title: "バックアップをダウンロード", isPrimary: true) {
                                startManualBackupExportFlow()
                            }
                            .disabled(manualBackupViewModel.isExporting || manualBackupViewModel.isInspecting || manualBackupViewModel.isRestoring || isSyncInteractionDisabled)

                            SettingsActionButton(title: "バックアップをアップロード（復元）", isPrimary: false) {
                                startManualBackupImportFlow()
                            }
                            .disabled(manualBackupViewModel.isExporting || manualBackupViewModel.isInspecting || manualBackupViewModel.isRestoring || isSyncInteractionDisabled)
                        }
                    }

                    if let manualErrorMessage = manualBackupViewModel.errorMessage {
                        Text(manualErrorMessage)
                            .font(SettingsDetailStyle.rowMetaFont)
                            .foregroundColor(.red)
                            .padding(.top, 2)
                    }
                }
            }

            if viewModel.requiresAppRestartNotice {
                SettingsSectionCard(title: "反映メッセージ", subtitle: "切替の反映タイミング") {
                    Text("設定変更は再起動後に反映されます。")
                        .font(SettingsDetailStyle.rowMetaFont)
                        .foregroundColor(SettingsDetailStyle.rowMetaText)
                }
            }

        }
        .task {
            await viewModel.loadInitialState(using: subscriptionService)
            manualBackupViewModel.load()
        }
        .overlay {
            if viewModel.isInitialLoadingOverlayVisible {
                ZStack {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                    ProgressView("サブスク状態を確認中...")
                        .font(SettingsDetailStyle.rowMetaFont)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white)
                        )
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showsExportPassphraseSheet) {
            BackupPassphraseSheet(
                title: "バックアップをダウンロード",
                subtitle: "バックアップファイルを暗号化するパスフレーズを設定します。",
                confirmButtonTitle: "ダウンロードを開始",
                requiresConfirmation: true,
                isProcessing: manualBackupViewModel.isExporting,
                minimumLength: ManualBackupSettingsViewModel.minimumPassphraseLength,
                onSubmit: { passphrase, confirmation in
                    showsExportPassphraseSheet = false
                    Task {
                        guard let exportedURL = await manualBackupViewModel.exportBackup(
                            passphrase: passphrase,
                            confirmation: confirmation
                        ) else {
                            return
                        }
                        shareItems = [exportedURL]
                        showsShareSheet = true
                    }
                },
                onCancel: {
                    showsExportPassphraseSheet = false
                }
            )
        }
        .sheet(isPresented: $showsImportPassphraseSheet) {
            BackupPassphraseSheet(
                title: "バックアップをアップロード",
                subtitle: "バックアップ作成時に設定したパスフレーズを入力してください。",
                confirmButtonTitle: "内容を確認",
                requiresConfirmation: false,
                isProcessing: manualBackupViewModel.isInspecting,
                minimumLength: ManualBackupSettingsViewModel.minimumPassphraseLength,
                onSubmit: { passphrase, _ in
                    guard let selectedImportURL else { return }
                    Task {
                        let isPrepared = await manualBackupViewModel.inspectBackup(
                            at: selectedImportURL,
                            passphrase: passphrase
                        )
                        showsImportPassphraseSheet = false
                        if isPrepared {
                            showsRestoreConfirmationSheet = true
                        } else {
                            discardSelectedImportFile()
                        }
                    }
                },
                onCancel: {
                    showsImportPassphraseSheet = false
                    discardSelectedImportFile()
                }
            )
            .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showsRestoreConfirmationSheet, onDismiss: {
            manualBackupViewModel.clearPendingRestore()
            discardSelectedImportFile()
        }) {
            if let preview = manualBackupViewModel.pendingRestorePreview {
                ManualRestoreConfirmationSheet(
                    preview: preview,
                    isRestoring: manualBackupViewModel.isRestoring,
                    onConfirm: {
                        Task {
                            let result = await manualBackupViewModel.restorePendingBackup()
                            if result != nil {
                                showsRestoreConfirmationSheet = false
                            }
                        }
                    },
                    onCancel: {
                        manualBackupViewModel.clearPendingRestore()
                        showsRestoreConfirmationSheet = false
                    }
                )
            } else {
                EmptyView()
            }
        }
        .interactiveDismissDisabled(manualBackupViewModel.isRestoring)
        .sheet(isPresented: $showsShareSheet, onDismiss: {
            cleanupSharedBackupFiles()
        }) {
            ActivityView(activityItems: shareItems)
        }
        .alert("バックアップファイルを選択", isPresented: $showsImportFileGuide) {
            Button("ファイルを開く") {
                showsFileImporter = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("拡張子 .esbackup のバックアップファイルを選択してください。")
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [Self.manualBackupContentType],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let firstURL = urls.first else { return }
                guard Self.isManualBackupFileURL(firstURL) else {
                    discardSelectedImportFile()
                    manualBackupViewModel.errorMessage = "拡張子 .esbackup のバックアップファイルを選択してください。"
                    return
                }
                do {
                    discardSelectedImportFile()
                    selectedImportURL = try copyImportedBackupToTemporaryDirectory(from: firstURL)
                    showsImportPassphraseSheet = true
                } catch {
                    discardSelectedImportFile()
                    manualBackupViewModel.errorMessage = error.localizedDescription
                }
            case .failure(let error):
                discardSelectedImportFile()
                manualBackupViewModel.errorMessage = error.localizedDescription
            }
        }
        .alert("Apple Accountにサインインしてください", isPresented: $showsAppleAccountSignInAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("クラウド同期を有効にするには、iPhoneの『設定』アプリ > 画面上部のApple Accountからサインインしてください。")
        }
    }

    private func setBackupEnabledWithPaywallGate(_ enabled: Bool) {
        guard ensureSubscriptionResolvedOrShowMessage(
            onError: { viewModel.errorMessage = $0 }
        ) else { return }

        guard enabled else {
            viewModel.setBackupEnabled(false)
            return
        }

        guard !Self.isBackupPaywallEnabled || viewModel.hasBackupAccess else {
            router.presentPaywall(.backup)
            return
        }

        if viewModel.needsAppleAccountSignIn {
            showsAppleAccountSignInAlert = true
            return
        }

        viewModel.setBackupEnabled(true)
    }

    private func startManualBackupExportFlow() {
        guard ensureSubscriptionResolvedOrShowMessage(
            onError: { manualBackupViewModel.errorMessage = $0 }
        ) else { return }
        guard !Self.isBackupPaywallEnabled || viewModel.hasBackupAccess else {
            router.presentPaywall(.backup)
            return
        }
        manualBackupViewModel.errorMessage = nil
        showsExportPassphraseSheet = true
    }

    private func startManualBackupImportFlow() {
        guard ensureSubscriptionResolvedOrShowMessage(
            onError: { manualBackupViewModel.errorMessage = $0 }
        ) else { return }
        guard !Self.isBackupPaywallEnabled || viewModel.hasBackupAccess else {
            router.presentPaywall(.backup)
            return
        }
        manualBackupViewModel.errorMessage = nil
        discardSelectedImportFile()
        showsImportFileGuide = true
    }

    private func ensureSubscriptionResolvedOrShowMessage(onError: (String) -> Void) -> Bool {
        guard viewModel.isSyncInteractionDisabled else {
            return true
        }
        onError("サブスク状態を確認中です。確認完了後に再度お試しください。")
        Task {
            await viewModel.refreshSubscriptionStatus(using: subscriptionService)
        }
        return false
    }

    private func copyImportedBackupToTemporaryDirectory(from sourceURL: URL) throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("imported-manual-backup-\(UUID().uuidString).esbackup")
        let isSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    private func discardSelectedImportFile() {
        guard let selectedImportURL else { return }
        do {
            try FileManager.default.removeItem(at: selectedImportURL)
        } catch {
            #if DEBUG
            NSLog("Failed to remove temporary backup file: %@", String(describing: error))
            #endif
        }
        self.selectedImportURL = nil
    }

    private func cleanupSharedBackupFiles() {
        for item in shareItems {
            guard let url = item as? URL,
                  url.isFileURL,
                  Self.isManualBackupFileURL(url)
            else {
                continue
            }
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                #if DEBUG
                NSLog("Failed to remove shared backup file: %@", String(describing: error))
                #endif
            }
        }
        shareItems = []
    }

    private static func isManualBackupFileURL(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "esbackup"
    }

    @ViewBuilder
    private func syncGuideMessage(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(HomeStyle.fabRed)
                .padding(.top, 1)
            Text(text)
                .font(SettingsDetailStyle.rowMetaFont)
                .foregroundColor(SettingsDetailStyle.rowMetaText)
        }
    }

    private func premiumLockedContent<Content: View>(
        isLocked: Bool,
        overlayPosition: PremiumLockOverlayPosition,
        ctaTitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: overlayPosition == .bottom ? .bottom : .center) {
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, isLocked && overlayPosition == .bottom ? PremiumLockCTAStyle.bottomReservedSpace : 0)
                .blur(radius: isLocked ? 1.4 : 0)
                .allowsHitTesting(!isLocked)
                .accessibilityHidden(isLocked)

            if isLocked {
                backupLockCTAButton(title: ctaTitle)
                    .padding(.horizontal, PremiumLockCTAStyle.horizontalInset)
                    .padding(.bottom, overlayPosition == .bottom ? 2 : 0)
            }
        }
    }

    private func backupLockCTAButton(title: String) -> some View {
        Button {
            router.presentPaywall(.backup)
        } label: {
            Text(title)
                .font(SettingsDetailStyle.actionFont)
                .foregroundColor(SettingsDetailStyle.actionPrimaryText)
                .frame(maxWidth: .infinity)
                .frame(height: PremiumLockCTAStyle.height)
                .background(SettingsDetailStyle.actionPrimaryFill)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#if canImport(RevenueCatUI)
private struct RevenueCatCustomerCenterContainer: View {
    var body: some View {
        NavigationStack {
            CustomerCenterView()
        }
    }
}
#endif

private struct SecuritySettingsView: View {
    @EnvironmentObject private var appPreferences: AppPreferencesStore

    var body: some View {
        SettingsDetailContainerView(
            title: "セキュリティ",
            subtitle: "パスコードと生体認証"
        ) {
            SettingsSectionCard(title: "ロック設定", subtitle: "アプリ起動時の保護") {
                SettingsToggleRow(title: "パスコードを使用", isOn: $appPreferences.passcodeEnabled)
                SettingsToggleRow(title: "Face ID / Touch ID", isOn: $appPreferences.biometricEnabled)
            }

            SettingsSectionCard(title: "自動ロック", subtitle: "非アクティブ時のロック") {
                HStack {
                    Text("自動ロックまで")
                        .font(SettingsDetailStyle.rowTitleFont)
                        .foregroundColor(SettingsDetailStyle.rowTitleText)
                    Spacer(minLength: 0)
                    Picker("自動ロックまで", selection: $appPreferences.autoLockInterval) {
                        ForEach(AppPreferencesStore.AutoLockInterval.allCases) { interval in
                            Text(interval.label).tag(interval)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .disabled(!appPreferences.isAutoLockConfigEnabled)
                }
            }
        }
    }
}

private struct DisplaySettingsView: View {
    @EnvironmentObject private var appPreferences: AppPreferencesStore
    private let themeModes: [AppPreferencesStore.ThemeMode] = [.system, .light, .dark]
    private let themeModeOptions = ["自動", "ライトモード", "ダークモード"]

    private var themeModeIndexBinding: Binding<Int> {
        Binding(
            get: { themeModes.firstIndex(of: appPreferences.themeMode) ?? 0 },
            set: { newValue in
                guard themeModes.indices.contains(newValue) else { return }
                appPreferences.themeMode = themeModes[newValue]
            }
        )
    }

    var body: some View {
        SettingsDetailContainerView(
            title: "表示",
            subtitle: "テーマを選択"
        ) {
            SettingsSectionCard(title: "テーマ", subtitle: "表示モード") {
                SettingsSegmentedControl(options: themeModeOptions, selection: themeModeIndexBinding)
                Text("選択した表示モードはアプリ全体に反映されます。")
                    .font(SettingsDetailStyle.rowMetaFont)
                    .foregroundColor(SettingsDetailStyle.rowMetaText)
            }
        }
    }
}

private struct LegalSettingsView: View {
    @Environment(\.openURL) private var openURL
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        SettingsDetailContainerView(
            title: "利用規約とプライバシーポリシー",
            subtitle: "利用に関する重要事項"
        ) {
            SettingsSectionCard(title: "ポリシー", subtitle: "公式ドキュメント") {
                VStack(spacing: 12) {
                    Text("外部ブラウザへ遷移します。")
                        .font(SettingsDetailStyle.rowMetaFont)
                        .foregroundColor(SettingsDetailStyle.rowMetaText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    SettingsLinkRow(title: "利用規約") {
                        guard let url = URL(string: "https://episodestocker.com/terms") else { return }
                        openURL(url)
                    }
                    SettingsLinkRow(title: "プライバシーポリシー") {
                        guard let url = URL(string: "https://episodestocker.com/privacy") else { return }
                        openURL(url)
                    }

                    Text("© \(currentYear) comado.studio All rights reserved.")
                        .font(SettingsDetailStyle.rowMetaFont)
                        .foregroundColor(SettingsDetailStyle.rowMetaText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
        }
    }
}

private struct SupportSettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var errorMessage: String?

    var body: some View {
        SettingsDetailContainerView(
            title: "サポート",
            subtitle: "メールで問い合わせ"
        ) {
            SettingsSectionCard(title: "お問い合わせ", subtitle: "サポート窓口へメール送信") {
                VStack(spacing: 10) {
                    SettingsActionButton(title: "メールアプリを開く", isPrimary: true) {
                        openSupportMail()
                    }
                    Text("デフォルトのメールクライアントが開きます。")
                        .font(SettingsDetailStyle.rowMetaFont)
                        .foregroundColor(SettingsDetailStyle.rowMetaText)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(SettingsDetailStyle.rowMetaFont)
                        .foregroundColor(.red)
                }
            }
        }
    }

    private func openSupportMail() {
        guard let url = URL(string: "mailto:support@episodestocker.com") else {
            errorMessage = "メールアプリを開けませんでした。"
            return
        }
        openURL(url) { accepted in
            if accepted {
                errorMessage = nil
            } else {
                errorMessage = "メールアプリを開けませんでした。"
            }
        }
    }
}

private struct SettingsLinkRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(SettingsDetailStyle.rowTitleFont)
                    .foregroundColor(SettingsDetailStyle.rowTitleText)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SettingsDetailStyle.linkIcon)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsSegmentedControl: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options.indices, id: \.self) { index in
                Button {
                    selection = index
                } label: {
                    Text(options[index])
                        .font(SettingsDetailStyle.segmentFont)
                        .foregroundColor(selection == index ? SettingsDetailStyle.segmentSelectedText : SettingsDetailStyle.segmentText)
                        .frame(maxWidth: .infinity)
                        .frame(height: SettingsDetailStyle.segmentHeight)
                        .background(
                            RoundedRectangle(cornerRadius: SettingsDetailStyle.segmentCornerRadius)
                                .fill(selection == index ? SettingsDetailStyle.segmentSelectedFill : SettingsDetailStyle.segmentFill)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    var isOn: Binding<Bool>
    var isDisabled: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(SettingsDetailStyle.rowTitleFont)
                .foregroundColor(SettingsDetailStyle.rowTitleText)

            Spacer(minLength: 0)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: SettingsDetailStyle.toggleTint))
                .disabled(isDisabled)
                .accessibilityLabel(title)
        }
    }
}

private struct SettingsDetailContainerView<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content
    @Environment(\.dismiss) private var dismiss

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = HomeStyle.primaryScreenContentWidth(for: proxy.size.width)
            let bottomInset = baseSafeAreaBottom()
            let topPadding = max(0, SettingsStyle.figmaTopInset - proxy.safeAreaInsets.top)
            let fullBottomPadding = HomeStyle.tabBarHeight + 16 + bottomInset
            let compactBottomPadding = bottomInset + 8

            ZStack(alignment: .top) {
                HomeStyle.screenBackground.ignoresSafeArea()

                ViewThatFits(in: .vertical) {
                    detailContent(
                        width: contentWidth,
                        topPadding: topPadding,
                        bottomPadding: compactBottomPadding
                    )

                    ScrollView {
                        detailContent(
                            width: contentWidth,
                            topPadding: topPadding,
                            bottomPadding: fullBottomPadding
                        )
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
            .edgeSwipeBack {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func detailContent(
        width: CGFloat,
        topPadding: CGFloat,
        bottomPadding: CGFloat
    ) -> some View {
        VStack(spacing: SettingsDetailStyle.sectionSpacing) {
            SettingsDetailHeader(title: title, subtitle: subtitle)
                .frame(width: width, alignment: .leading)

            Rectangle()
                .fill(HomeStyle.outline)
                .frame(width: width, height: HomeStyle.dividerHeight)

            VStack(spacing: SettingsDetailStyle.sectionSpacing) {
                content
            }
            .frame(width: width)
        }
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity)
    }
}

private enum SettingsDetailStyle {
    static let sectionSpacing: CGFloat = 16
    static let headerHeight: CGFloat = 56

    static let cardCornerRadius: CGFloat = 12
    static let cardBorderWidth: CGFloat = 0.66

    static let segmentHeight: CGFloat = 36
    static let segmentCornerRadius: CGFloat = 12

    static let actionHeight: CGFloat = 44
    static let actionCornerRadius: CGFloat = 12

    static let headerFont = AppTypography.sectionTitle
    static let subheaderFont = AppTypography.subtext
    static let sectionTitleFont = AppTypography.sectionTitle
    static let sectionSubtitleFont = AppTypography.subtext
    static let rowTitleFont = AppTypography.bodyEmphasis
    static let rowValueFont = AppTypography.body
    static let rowMetaFont = AppTypography.meta
    static let actionFont = AppTypography.bodyEmphasis
    static let segmentFont = AppTypography.subtextEmphasis

    static let headerText = HomeStyle.textPrimary
    static let subheaderText = HomeStyle.textSecondary
    static let sectionTitleText = HomeStyle.textPrimary
    static let sectionSubtitleText = HomeStyle.textSecondary
    static let rowTitleText = HomeStyle.textPrimary
    static let rowValueText = Color(hex: "4A5565")
    static let rowMetaText = HomeStyle.textSecondary

    static let cardFill = Color.white
    static let cardBorder = Color(hex: "E5E7EB")

    static let cardShadowPrimary = Color.black.opacity(0.12)
    static let cardShadowPrimaryRadius: CGFloat = 2
    static let cardShadowPrimaryY: CGFloat = 1
    static let cardShadowSecondary = Color.black.opacity(0.06)
    static let cardShadowSecondaryRadius: CGFloat = 6
    static let cardShadowSecondaryY: CGFloat = 3

    static let actionPrimaryFill = HomeStyle.fabRed
    static let actionPrimaryText = Color.white
    static let actionSecondaryFill = HomeStyle.fabRed.opacity(0.10)
    static let actionSecondaryText = HomeStyle.fabRed
    static let actionSecondaryBorder = HomeStyle.fabRed.opacity(0.35)

    static let segmentSelectedFill = HomeStyle.fabRed
    static let segmentSelectedText = Color.white
    static let segmentFill = Color(hex: "F3F4F6")
    static let segmentText = Color(hex: "4A5565")

    static let toggleTint = HomeStyle.fabRed
    static let linkIcon = HomeStyle.fabRed
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppRouter())
            .environmentObject(PremiumAccessViewModel())
            .environmentObject(AppPreferencesStore())
    }
}
