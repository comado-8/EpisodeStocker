import SwiftUI

struct SettingsView: View {
    private let items: [SettingsItemData] = [
        .init(title: "サブスクリプション", detail: "プラン/更新日/試用残日数", systemImage: "creditcard", destination: .subscription),
        .init(title: "バックアップ", detail: "クラウド/手動バックアップ", systemImage: "icloud", destination: .backup),
        .init(title: "セキュリティ", detail: "パスコード/生体認証", systemImage: "lock", destination: .security),
        .init(title: "表示", detail: "テーマ・フォントサイズ・一覧表示", systemImage: "textformat.size", destination: .display),
        .init(title: "法務", detail: "利用規約・プライバシー", systemImage: "doc.text", destination: .legal)
    ]

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = HomeStyle.contentWidth(for: proxy.size.width)
            let bottomInset = baseSafeAreaBottom()
            let topPadding = max(0, SettingsStyle.figmaTopInset - proxy.safeAreaInsets.top)

            ZStack {
                HomeStyle.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SettingsStyle.sectionSpacing) {
                        SettingsHeaderView()
                            .frame(width: contentWidth, alignment: .leading)

                        Rectangle()
                            .fill(HomeStyle.outline)
                            .frame(width: contentWidth, height: HomeStyle.dividerHeight)

                        VStack(spacing: SettingsStyle.cardSpacing) {
                            ForEach(items) { item in
                                NavigationLink {
                                    SettingsDestinationView(destination: item.destination)
                                } label: {
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

private enum SettingsDestination {
    case subscription
    case backup
    case security
    case display
    case legal
}

private struct SettingsDestinationView: View {
    let destination: SettingsDestination

    var body: some View {
        switch destination {
        case .subscription:
            SubscriptionSettingsView()
        case .backup:
            BackupSettingsView()
        case .security:
            SecuritySettingsView()
        case .display:
            DisplaySettingsView()
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

    static let headerFont = Font.custom("Roboto-Bold", size: 20)
    static let subheaderFont = Font.custom("Roboto", size: 13)
    static let rowTitleFont = Font.custom("Roboto-Bold", size: 15)
    static let rowBodyFont = Font.custom("Roboto", size: 12)

    static let headerText = Color(hex: "2A2525")
    static let subheaderText = Color(hex: "6B7280")
    static let rowTitleText = Color(hex: "2A2525")
    static let rowBodyText = Color(hex: "6B7280")

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

private extension SettingsView {
    func baseSafeAreaBottom() -> CGFloat {
        #if canImport(UIKit)
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        if let window = windowScene?.windows.first(where: { $0.isKeyWindow }) {
            return window.safeAreaInsets.bottom
        }
        #endif
        return 0
    }
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

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SettingsDetailStyle.sectionTitleFont)
                    .foregroundColor(SettingsDetailStyle.sectionTitleText)
                Text(subtitle)
                    .font(SettingsDetailStyle.sectionSubtitleFont)
                    .foregroundColor(SettingsDetailStyle.sectionSubtitleText)
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

@MainActor
private struct SubscriptionSettingsView: View {
    @StateObject private var viewModel: SubscriptionSettingsViewModel

    init(viewModel: SubscriptionSettingsViewModel? = nil) {
        _viewModel = StateObject(
            wrappedValue: viewModel ?? SubscriptionSettingsViewModel(service: StoreKitSubscriptionService())
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
    }
}

@MainActor
private struct BackupSettingsView: View {
    @StateObject private var viewModel: BackupSettingsViewModel
    private let subscriptionService: SubscriptionService

    init(
        viewModel: BackupSettingsViewModel? = nil,
        subscriptionService: SubscriptionService = StoreKitSubscriptionService()
    ) {
        self.subscriptionService = subscriptionService
        _viewModel = StateObject(
            wrappedValue: viewModel ?? BackupSettingsViewModel(cloudBackupService: CloudKitBackupService())
        )
    }

    private var backupBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isBackupEnabled },
            set: { viewModel.setBackupEnabled($0) }
        )
    }

    private var lastBackupText: String {
        guard let lastBackupAt = viewModel.lastBackupAt else {
            return "未実行"
        }
        return Self.backupDateFormatter.string(from: lastBackupAt)
    }

    private static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    var body: some View {
        SettingsDetailContainerView(
            title: "バックアップ",
            subtitle: "クラウドと手動バックアップ"
        ) {
            SettingsSectionCard(title: "クラウドバックアップ", subtitle: "自動バックアップの状態") {
                Toggle(isOn: backupBinding) {
                    Text("クラウド同期を有効にする")
                        .font(SettingsDetailStyle.rowTitleFont)
                        .foregroundColor(SettingsDetailStyle.rowTitleText)
                }
                .toggleStyle(SwitchToggleStyle(tint: SettingsDetailStyle.toggleTint))
                .disabled(viewModel.isRunningBackup)

                SettingsKeyValueRow(title: "可用性", value: viewModel.availabilityMessage)

                VStack(spacing: 10) {
                    SettingsKeyValueRow(title: "最終バックアップ", value: lastBackupText)
                    SettingsKeyValueRow(title: "保存容量", value: "18.4 MB")
                }
                .padding(.top, 4)
            }

            SettingsSectionCard(title: "手動バックアップ", subtitle: "必要なタイミングで保存") {
                VStack(spacing: 10) {
                    SettingsActionButton(
                        title: viewModel.isRunningBackup ? "バックアップ実行中..." : "今すぐバックアップ",
                        isPrimary: true
                    ) {
                        Task { await viewModel.runManualBackup() }
                    }
                    .disabled(viewModel.isRunningBackup)
                    SettingsActionButton(title: "バックアップ履歴を見る", isPrimary: false) {}
                }
            }

            if let errorMessage = viewModel.errorMessage {
                SettingsSectionCard(title: "バックアップ状態", subtitle: "実行結果") {
                    Text(errorMessage)
                        .font(SettingsDetailStyle.rowMetaFont)
                        .foregroundColor(.red)
                }
            }
        }
        .task {
            await viewModel.load()
            await viewModel.refreshSubscriptionStatus(using: subscriptionService)
        }
    }
}

private struct SecuritySettingsView: View {
    @State private var passcodeEnabled = true
    @State private var biometricEnabled = false

    var body: some View {
        SettingsDetailContainerView(
            title: "セキュリティ",
            subtitle: "パスコードと生体認証"
        ) {
            SettingsSectionCard(title: "ロック設定", subtitle: "アプリ起動時の保護") {
                Toggle(isOn: $passcodeEnabled) {
                    Text("パスコードを使用")
                        .font(SettingsDetailStyle.rowTitleFont)
                        .foregroundColor(SettingsDetailStyle.rowTitleText)
                }
                .toggleStyle(SwitchToggleStyle(tint: SettingsDetailStyle.toggleTint))

                Toggle(isOn: $biometricEnabled) {
                    Text("Face ID / Touch ID")
                        .font(SettingsDetailStyle.rowTitleFont)
                        .foregroundColor(SettingsDetailStyle.rowTitleText)
                }
                .toggleStyle(SwitchToggleStyle(tint: SettingsDetailStyle.toggleTint))
            }

            SettingsSectionCard(title: "自動ロック", subtitle: "非アクティブ時のロック") {
                VStack(spacing: 10) {
                    SettingsKeyValueRow(title: "自動ロックまで", value: "2分")
                    SettingsKeyValueRow(title: "試行回数制限", value: "10回")
                }
            }
        }
    }
}

private struct DisplaySettingsView: View {
    @State private var themeIndex = 0
    @State private var fontScaleIndex = 1

    private let themeOptions = ["ライト", "ダーク", "自動"]
    private let fontScaleOptions = ["小", "標準", "大"]

    var body: some View {
        SettingsDetailContainerView(
            title: "表示",
            subtitle: "テーマとフォントを調整"
        ) {
            SettingsSectionCard(title: "テーマ", subtitle: "表示モードを選択") {
                SettingsSegmentedControl(options: themeOptions, selection: $themeIndex)
            }

            SettingsSectionCard(title: "フォントサイズ", subtitle: "読みやすさの調整") {
                SettingsSegmentedControl(options: fontScaleOptions, selection: $fontScaleIndex)
            }

            SettingsSectionCard(title: "一覧の表示", subtitle: "Home画面の表示形式") {
                SettingsKeyValueRow(title: "ホーム一覧", value: "リスト表示（固定）")
            }
        }
    }
}

private struct LegalSettingsView: View {
    var body: some View {
        SettingsDetailContainerView(
            title: "法務",
            subtitle: "利用規約とプライバシー"
        ) {
            SettingsSectionCard(title: "ドキュメント", subtitle: "利用に関する重要事項") {
                VStack(spacing: 12) {
                    SettingsLinkRow(title: "利用規約", detail: "最終更新 2026/01/15")
                    SettingsLinkRow(title: "プライバシーポリシー", detail: "最終更新 2026/01/15")
                    SettingsLinkRow(title: "ライセンス", detail: "オープンソース情報")
                }
            }

            SettingsSectionCard(title: "サポート", subtitle: "問い合わせと不具合報告") {
                VStack(spacing: 10) {
                    SettingsActionButton(title: "問い合わせフォームを開く", isPrimary: true) {}
                    SettingsActionButton(title: "バージョン情報を確認", isPrimary: false) {}
                }
            }
        }
    }
}

private struct SettingsLinkRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SettingsDetailStyle.rowTitleFont)
                    .foregroundColor(SettingsDetailStyle.rowTitleText)
                Text(detail)
                    .font(SettingsDetailStyle.rowMetaFont)
                    .foregroundColor(SettingsDetailStyle.rowMetaText)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(SettingsDetailStyle.linkIcon)
        }
        .padding(.vertical, 4)
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

            ZStack {
                HomeStyle.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SettingsDetailStyle.sectionSpacing) {
                        SettingsDetailHeader(title: title, subtitle: subtitle)
                            .frame(width: contentWidth, alignment: .leading)

                        Rectangle()
                            .fill(HomeStyle.outline)
                            .frame(width: contentWidth, height: HomeStyle.dividerHeight)

                        VStack(spacing: SettingsDetailStyle.sectionSpacing) {
                            content
                        }
                        .frame(width: contentWidth)
                    }
                    .padding(.top, topPadding)
                    .padding(.bottom, HomeStyle.tabBarHeight + 16 + bottomInset)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func baseSafeAreaBottom() -> CGFloat {
        #if canImport(UIKit)
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        if let window = windowScene?.windows.first(where: { $0.isKeyWindow }) {
            return window.safeAreaInsets.bottom
        }
        #endif
        return 0
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

    static let headerFont = Font.custom("Roboto-Bold", size: 20)
    static let subheaderFont = Font.custom("Roboto", size: 13)
    static let sectionTitleFont = Font.custom("Roboto-Bold", size: 14)
    static let sectionSubtitleFont = Font.custom("Roboto", size: 12)
    static let rowTitleFont = Font.custom("Roboto-Medium", size: 13)
    static let rowValueFont = Font.custom("Roboto", size: 13)
    static let rowMetaFont = Font.custom("Roboto", size: 11)
    static let actionFont = Font.custom("Roboto-Bold", size: 14)
    static let segmentFont = Font.custom("Roboto-Medium", size: 13)

    static let headerText = Color(hex: "2A2525")
    static let subheaderText = Color(hex: "6B7280")
    static let sectionTitleText = Color(hex: "2A2525")
    static let sectionSubtitleText = Color(hex: "6B7280")
    static let rowTitleText = Color(hex: "2A2525")
    static let rowValueText = Color(hex: "4A5565")
    static let rowMetaText = Color(hex: "6B7280")

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
    }
}
