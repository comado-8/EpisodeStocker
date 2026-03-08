import SwiftData
import SwiftUI
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
                let contentWidth = HomeStyle.contentWidth(for: proxy.size.width)
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
    @StateObject private var viewModel: SubscriptionSettingsViewModel
    @State private var showsRevenueCatPaywall = false
    @State private var showsCustomerCenter = false

    init(viewModel: SubscriptionSettingsViewModel? = nil) {
        _viewModel = StateObject(
            wrappedValue: viewModel ?? SubscriptionSettingsViewModel(service: SubscriptionServiceFactory.makeService())
        )
    }

    private var planLabel: String {
        switch viewModel.status.plan {
        case .free:
            return "Free"
        case .monthly:
            return "月額"
        case .yearly:
            return "年額"
        }
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    var body: some View {
        SettingsDetailContainerView(
            title: "サブスクリプション",
            subtitle: "プラン情報と更新日を確認"
        ) {
            SettingsSectionCard(title: "現在のプラン", subtitle: "利用中のプランと更新スケジュール") {
                VStack(spacing: 10) {
                    SettingsKeyValueRow(title: "プラン", value: planLabel)
                    SettingsKeyValueRow(title: "更新日", value: expiryDateText)
                    if let trialText {
                        SettingsKeyValueRow(title: "試用残日数", value: trialText)
                    }
                }
                .padding(.top, 4)
            }

            SettingsSectionCard(title: "プランの管理", subtitle: "アップグレードや解約の操作") {
                VStack(spacing: 10) {
                    SettingsActionButton(title: "月額プランに変更", isPrimary: true) {
                        Task { await viewModel.purchase(productID: SubscriptionCatalog.monthlyProductID) }
                    }
                    .disabled(viewModel.isLoading)
                    SettingsActionButton(title: "年額プランに変更", isPrimary: false) {
                        Task { await viewModel.purchase(productID: SubscriptionCatalog.yearlyProductID) }
                    }
                    .disabled(viewModel.isLoading)
                    SettingsActionButton(title: "購入を復元", isPrimary: false) {
                        Task { await viewModel.restorePurchases() }
                    }
                    .disabled(viewModel.isLoading)
                    #if canImport(RevenueCatUI)
                    SettingsActionButton(title: "RevenueCat Paywallを開く", isPrimary: false) {
                        showsRevenueCatPaywall = true
                    }
                    .disabled(viewModel.isLoading)
                    SettingsActionButton(title: "Customer Centerを開く", isPrimary: false) {
                        showsCustomerCenter = true
                    }
                    .disabled(viewModel.isLoading)
                    #endif
                }
            }

            if let errorMessage = viewModel.errorMessage {
                SettingsSectionCard(title: "課金状態", subtitle: "実行結果") {
                    Text(errorMessage)
                        .font(SettingsDetailStyle.rowMetaFont)
                        .foregroundColor(.red)
                }
            }
        }
        .task {
            await viewModel.load()
        }
        #if canImport(RevenueCatUI)
        .sheet(isPresented: $showsRevenueCatPaywall) {
            RevenueCatPaywallContainer()
        }
        .sheet(isPresented: $showsCustomerCenter) {
            RevenueCatCustomerCenterContainer()
        }
        #endif
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
    @EnvironmentObject private var premiumAccess: PremiumAccessViewModel
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
           let parsedFlag = parseEnvironmentBoolean(rawFlag)
        {
            return parsedFlag
        }
        // TODO(TAX-COMPLIANCE): 税務情報フォーム対応後にこのDEBUGバイパスを削除する。
        // 一時対応: 分析タブ/エクスポートと同様、Debugのみバックアップ課金ゲートを無効化する。
        // 課金テスト再開時は、このフラグを削除するか DEBUG でも true を返して復帰する。
        #if DEBUG
        return false
        #else
        return true
        #endif
    }

    private static func parseEnvironmentBoolean(_ raw: String) -> Bool? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
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
                isEntitlementCheckEnabled: Self.isBackupPaywallEnabled
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
        guard viewModel.isBackupEnabled else {
            return "オフ"
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

    var body: some View {
        SettingsDetailContainerView(
            title: "同期・バックアップ",
            subtitle: "クラウド同期の状態管理"
        ) {
            SettingsSectionCard(
                title: "クラウド同期",
                subtitle: "有効化と状態",
                headerAccessory: { ProFeatureBadge() }
            ) {
                Toggle(isOn: backupBinding) {
                    Text("クラウド同期を有効にする")
                        .font(SettingsDetailStyle.rowTitleFont)
                        .foregroundColor(SettingsDetailStyle.rowTitleText)
                }
                .toggleStyle(SwitchToggleStyle(tint: SettingsDetailStyle.toggleTint))

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

                if let visibleErrorMessage {
                    Text(visibleErrorMessage)
                        .font(SettingsDetailStyle.rowMetaFont)
                        .foregroundColor(.red)
                        .padding(.top, 2)
                }
            }

            SettingsSectionCard(
                title: "手動バックアップ",
                subtitle: "ダウンロード/アップロード",
                headerAccessory: { ProFeatureBadge() }
            ) {
                Text("通常はiCloudでのデータ同期の利用をおすすめします。手動バックアップは必要な場合にご利用ください。")
                    .font(SettingsDetailStyle.rowMetaFont)
                    .foregroundColor(SettingsDetailStyle.rowMetaText)

                SettingsKeyValueRow(title: "最終ダウンロード日時", value: manualLastExportText)
                SettingsKeyValueRow(title: "最終アップロード日時", value: manualLastRestoreText)

                VStack(spacing: 10) {
                    SettingsActionButton(title: "バックアップをダウンロード", isPrimary: true) {
                        startManualBackupExportFlow()
                    }
                    .disabled(manualBackupViewModel.isExporting || manualBackupViewModel.isInspecting || manualBackupViewModel.isRestoring)

                    SettingsActionButton(title: "バックアップをアップロード（復元）", isPrimary: false) {
                        startManualBackupImportFlow()
                    }
                    .disabled(manualBackupViewModel.isExporting || manualBackupViewModel.isInspecting || manualBackupViewModel.isRestoring)
                }

                if let manualErrorMessage = manualBackupViewModel.errorMessage {
                    Text(manualErrorMessage)
                        .font(SettingsDetailStyle.rowMetaFont)
                        .foregroundColor(.red)
                        .padding(.top, 2)
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
            await viewModel.load()
            await viewModel.refreshSubscriptionStatus(using: subscriptionService)
            manualBackupViewModel.load()
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
        guard enabled else {
            viewModel.setBackupEnabled(false)
            return
        }

        guard !Self.isBackupPaywallEnabled || premiumAccess.hasAccess(to: .backup) else {
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
        guard !Self.isBackupPaywallEnabled || premiumAccess.hasAccess(to: .backup) else {
            router.presentPaywall(.backup)
            return
        }
        manualBackupViewModel.errorMessage = nil
        showsExportPassphraseSheet = true
    }

    private func startManualBackupImportFlow() {
        guard !Self.isBackupPaywallEnabled || premiumAccess.hasAccess(to: .backup) else {
            router.presentPaywall(.backup)
            return
        }
        manualBackupViewModel.errorMessage = nil
        discardSelectedImportFile()
        showsImportFileGuide = true
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
            print("Failed to remove temporary backup file: \(error)")
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
                print("Failed to remove shared backup file: \(error)")
                #endif
            }
        }
        shareItems = []
    }

    private static func isManualBackupFileURL(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "esbackup"
    }
}

#if canImport(RevenueCatUI)
private struct RevenueCatPaywallContainer: View {
    var body: some View {
        PaywallView(displayCloseButton: true)
    }
}

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
                Toggle(isOn: $appPreferences.passcodeEnabled) {
                    Text("パスコードを使用")
                        .font(SettingsDetailStyle.rowTitleFont)
                        .foregroundColor(SettingsDetailStyle.rowTitleText)
                }
                .toggleStyle(SwitchToggleStyle(tint: SettingsDetailStyle.toggleTint))

                Toggle(isOn: $appPreferences.biometricEnabled) {
                    Text("Face ID / Touch ID")
                        .font(SettingsDetailStyle.rowTitleFont)
                        .foregroundColor(SettingsDetailStyle.rowTitleText)
                }
                .toggleStyle(SwitchToggleStyle(tint: SettingsDetailStyle.toggleTint))
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

                    Text("© 2026 comado.studio All rights reserved.")
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
            .padding(.vertical, 4)
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
            let contentWidth = HomeStyle.contentWidth(for: proxy.size.width)
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
    static let actionSecondaryFill = Color.white
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
