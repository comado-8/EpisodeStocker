import SwiftUI

struct AnalyticsView: View {
    var body: some View {
        GeometryReader { proxy in
            let contentWidth = HomeStyle.contentWidth(for: proxy.size.width)
            let topPadding = max(0, AnalyticsStyle.figmaTopInset - proxy.safeAreaInsets.top)

            ZStack {
                HomeStyle.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 12) {
                    Text("分析")
                        .font(AnalyticsStyle.headerFont)
                        .foregroundColor(AnalyticsStyle.headerText)

                    Text("タグ/カテゴリ別の利用数や未公開率のグラフをここに表示する予定です。")
                        .font(AnalyticsStyle.bodyFont)
                        .foregroundColor(AnalyticsStyle.bodyText)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.top, topPadding)
                .padding(.bottom, HomeStyle.tabBarHeight + 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private enum AnalyticsStyle {
    static let figmaTopInset: CGFloat = 59
    static let headerFont = AppTypography.screenTitle
    static let bodyFont = AppTypography.body
    static let headerText = HomeStyle.textPrimary
    static let bodyText = HomeStyle.textSecondary
}

struct AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { AnalyticsView() }
    }
}
