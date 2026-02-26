import SwiftData
import SwiftUI

struct AnalyticsView: View {
    @Query(
        filter: #Predicate<Episode> { $0.isSoftDeleted == false },
        sort: [SortDescriptor(\Episode.updatedAt, order: .reverse)]
    )
    private var episodes: [Episode]

    @Query(
        filter: #Predicate<UnlockLog> { $0.isSoftDeleted == false },
        sort: [SortDescriptor(\UnlockLog.talkedAt, order: .reverse)]
    )
    private var unlockLogs: [UnlockLog]

    private var monthTalkCount: Int {
        unlockLogs.filter {
            Calendar.current.isDate($0.talkedAt, equalTo: Date(), toGranularity: .month)
        }.count
    }

    private var talkedRankingTop10: [AnalyticsEpisodeRankItem] {
        episodes
            .sorted { lhs, rhs in
                if lhs.talkedCount != rhs.talkedCount {
                    return lhs.talkedCount > rhs.talkedCount
                }
                let lhsLatest = lhs.latestTalkedAt ?? .distantPast
                let rhsLatest = rhs.latestTalkedAt ?? .distantPast
                if lhsLatest != rhsLatest {
                    return lhsLatest > rhsLatest
                }
                return lhs.updatedAt > rhs.updatedAt
            }
            .prefix(10)
            .enumerated()
            .map { index, episode in
                AnalyticsEpisodeRankItem(
                    rank: index + 1,
                    title: episode.title,
                    metric: "\(episode.talkedCount)回",
                    submetric: episode.latestTalkedAt.map { "最終 \(AnalyticsStyle.dateFormatter.string(from: $0))" } ?? "未トーク"
                )
            }
    }

    private var notTalkedRecentlyTop10: [AnalyticsEpisodeRankItem] {
        episodes
            .sorted { lhs, rhs in
                let lhsLatest = lhs.latestTalkedAt
                let rhsLatest = rhs.latestTalkedAt

                if lhsLatest == nil && rhsLatest != nil {
                    return true
                }
                if lhsLatest != nil && rhsLatest == nil {
                    return false
                }

                let lhsDate = lhsLatest ?? .distantFuture
                let rhsDate = rhsLatest ?? .distantFuture
                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
                return lhs.updatedAt < rhs.updatedAt
            }
            .prefix(10)
            .enumerated()
            .map { index, episode in
                AnalyticsEpisodeRankItem(
                    rank: index + 1,
                    title: episode.title,
                    metric: episode.latestTalkedAt.map { AnalyticsStyle.dateFormatter.string(from: $0) } ?? "未トーク",
                    submetric: "話した回数 \(episode.talkedCount)回"
                )
            }
    }

    private var mediaTypeBreakdown: [AnalyticsMetricItem] {
        var counts: [String: Int] = [:]
        for log in unlockLogs {
            let trimmed = log.mediaType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let key = trimmed.isEmpty ? "未設定" : trimmed
            counts[key, default: 0] += 1
        }

        return counts
            .map { AnalyticsMetricItem(label: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.label < rhs.label
            }
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = HomeStyle.contentWidth(for: proxy.size.width)
            let topPadding = max(0, AnalyticsStyle.figmaTopInset - proxy.safeAreaInsets.top)

            ZStack {
                HomeStyle.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("分析")
                            .font(AnalyticsStyle.headerFont)
                            .foregroundColor(AnalyticsStyle.headerText)

                        AnalyticsSummaryCard(
                            title: "今月のトーク回数",
                            valueText: "\(monthTalkCount)回"
                        )

                        AnalyticsSectionCard(title: "話した回数ランキング Top10") {
                            if talkedRankingTop10.isEmpty {
                                AnalyticsEmptyText(text: "データがありません")
                            } else {
                                ForEach(talkedRankingTop10) { item in
                                    AnalyticsRankRow(item: item)
                                }
                            }
                        }

                        AnalyticsSectionCard(title: "最近話していないエピソード Top10") {
                            if notTalkedRecentlyTop10.isEmpty {
                                AnalyticsEmptyText(text: "データがありません")
                            } else {
                                ForEach(notTalkedRecentlyTop10) { item in
                                    AnalyticsRankRow(item: item)
                                }
                            }
                        }

                        AnalyticsSectionCard(title: "媒体別トーク回数") {
                            if mediaTypeBreakdown.isEmpty {
                                AnalyticsEmptyText(text: "データがありません")
                            } else {
                                ForEach(mediaTypeBreakdown) { item in
                                    HStack {
                                        Text(item.label)
                                            .font(AnalyticsStyle.bodyFont)
                                            .foregroundColor(AnalyticsStyle.headerText)
                                        Spacer(minLength: 0)
                                        Text("\(item.count)回")
                                            .font(AnalyticsStyle.bodyFont)
                                            .foregroundColor(AnalyticsStyle.bodyText)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.top, topPadding)
                    .padding(.bottom, HomeStyle.tabBarHeight + 16)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct AnalyticsMetricItem: Identifiable {
    let label: String
    let count: Int

    var id: String { label }
}

private struct AnalyticsEpisodeRankItem: Identifiable {
    let rank: Int
    let title: String
    let metric: String
    let submetric: String

    var id: String { "\(rank)-\(title)" }
}

private enum AnalyticsStyle {
    static let figmaTopInset: CGFloat = 59
    static let headerFont = AppTypography.screenTitle
    static let sectionTitleFont = AppTypography.bodyEmphasis
    static let bodyFont = AppTypography.body
    static let subtextFont = AppTypography.subtext
    static let headerText = HomeStyle.textPrimary
    static let bodyText = HomeStyle.textSecondary

    static let cardFill = Color(hex: "FFFFFF")
    static let cardBorder = Color(hex: "E5E7EB")

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
}

private struct AnalyticsSummaryCard: View {
    let title: String
    let valueText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AnalyticsStyle.sectionTitleFont)
                .foregroundColor(AnalyticsStyle.headerText)

            Text(valueText)
                .font(AppTypography.screenTitle)
                .foregroundColor(HomeStyle.fabRed)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AnalyticsStyle.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AnalyticsStyle.cardBorder, lineWidth: 1)
                )
        )
    }
}

private struct AnalyticsSectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AnalyticsStyle.sectionTitleFont)
                .foregroundColor(AnalyticsStyle.headerText)

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AnalyticsStyle.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AnalyticsStyle.cardBorder, lineWidth: 1)
                )
        )
    }
}

private struct AnalyticsRankRow: View {
    let item: AnalyticsEpisodeRankItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(item.rank).")
                .font(AnalyticsStyle.subtextFont)
                .foregroundColor(HomeStyle.subtitle)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(AnalyticsStyle.bodyFont)
                    .foregroundColor(AnalyticsStyle.headerText)
                    .lineLimit(1)

                Text(item.submetric)
                    .font(AnalyticsStyle.subtextFont)
                    .foregroundColor(AnalyticsStyle.bodyText)
            }

            Spacer(minLength: 0)

            Text(item.metric)
                .font(AnalyticsStyle.bodyFont)
                .foregroundColor(HomeStyle.fabRed)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AnalyticsEmptyText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AnalyticsStyle.subtextFont)
            .foregroundColor(AnalyticsStyle.bodyText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { AnalyticsView() }
    }
}
