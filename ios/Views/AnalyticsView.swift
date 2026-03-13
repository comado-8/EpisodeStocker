import SwiftData
import SwiftUI

struct AnalyticsView: View {
    @Query(
        filter: #Predicate<Episode> { $0.isSoftDeleted == false },
        sort: [SortDescriptor(\Episode.updatedAt, order: .reverse)]
    )
    private var episodes: [Episode]

    @StateObject private var viewModel = AnalyticsMVPViewModel()

    private var refreshToken: Int {
        var hasher = Hasher()
        for episode in episodes.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(episode.id)
            hasher.combine(episode.updatedAt.timeIntervalSince1970)
            hasher.combine(episode.title)

            for tag in episode.tags.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
                hasher.combine(tag.id)
                hasher.combine(tag.updatedAt.timeIntervalSince1970)
                hasher.combine(tag.name)
                hasher.combine(tag.isSoftDeleted)
            }

            for log in episode.activeUnlockLogs.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
                hasher.combine(log.id)
                hasher.combine(log.updatedAt.timeIntervalSince1970)
                hasher.combine(log.talkedAt.timeIntervalSince1970)
                hasher.combine(log.reaction)
            }
        }
        return hasher.finalize()
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = HomeStyle.primaryScreenContentWidth(for: proxy.size.width)
            let topPadding = max(0, AnalyticsStyle.figmaTopInset - proxy.safeAreaInsets.top)

            ZStack {
                AnalyticsStyle.background.ignoresSafeArea()

                if viewModel.snapshot == nil, viewModel.isLoading {
                    ProgressView("分析を計算中…")
                        .font(AppTypography.body)
                        .foregroundColor(AnalyticsStyle.supportingText)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            AnalyticsHeaderView()

                            if let snapshot = viewModel.snapshot {
                                AnalyticsSectionHeader(title: "掘り起こしエピソード")
                                AnalyticsDigUpCard(items: snapshot.digUpSuggestions)

                                AnalyticsSectionHeader(title: "エピソード分析")
                                AnalyticsTopTalkedCard(items: snapshot.topTalkedEpisodes)
                                AnalyticsDormantCard(items: snapshot.dormantEpisodes)
                                AnalyticsStrongCard(items: snapshot.strongEpisodes)
                                AnalyticsOverusedCard(items: snapshot.overusedEpisodes)

                                AnalyticsSectionHeader(title: "ジャンル分析")
                                AnalyticsTagTalkCountCard(items: snapshot.tagTalkCounts)
                                AnalyticsTagHitRateCard(items: snapshot.tagHitRates)
                            } else if let errorMessage = viewModel.errorMessage {
                                AnalyticsErrorCard(message: errorMessage)
                            } else {
                                AnalyticsErrorCard(message: "分析対象のデータがありません。")
                            }
                        }
                        .frame(width: contentWidth, alignment: .leading)
                        .padding(.top, topPadding)
                        .padding(.bottom, HomeStyle.tabBarHeight + 16)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: refreshToken) {
            await viewModel.refresh(episodes: episodes)
        }
    }
}

private struct AnalyticsHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("分析ダッシュボード")
                .font(AnalyticsStyle.titleFont)
                .foregroundColor(AnalyticsStyle.titleText)

            Text("エピソード履歴の傾向を確認")
                .font(AnalyticsStyle.descriptionFont)
                .foregroundColor(AnalyticsStyle.descriptionText)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 8)
    }
}

private struct AnalyticsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppTypography.sectionTitle)
            .foregroundColor(AnalyticsStyle.sectionTitle)
            .padding(.top, 4)
            .padding(.horizontal, 2)
    }
}

private struct AnalyticsDigUpCard: View {
    let items: [DigUpSuggestionItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AnalyticsCardHeader(
                icon: "sparkles",
                iconFill: Color(hex: "EA580C"),
                title: "最近話していないウケるネタ"
            )

            if items.isEmpty {
                AnalyticsEmptyLabel(text: "条件を満たす候補がありません")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items) { item in
                        NavigationLink(value: item.episodeID) {
                            AnalyticsEpisodeRow(
                                title: item.title,
                                subtitle: "最終 \(AnalyticsStyle.dateFormatter.string(from: item.lastTalkedAt))",
                                trailing: "\(AnalyticsStyle.percent(item.hitRate)) / \(item.talkCount)回"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .analyticsCardStyle()
    }
}

private struct AnalyticsTopTalkedCard: View {
    let items: [EpisodeTopItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AnalyticsCardHeader(
                icon: "star.fill",
                iconFill: AnalyticsStyle.accentRed,
                title: "よく使われているエピソード"
            )

            if items.isEmpty {
                AnalyticsEmptyLabel(text: "データがありません")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items) { item in
                        NavigationLink(value: item.episodeID) {
                            AnalyticsEpisodeRow(
                                title: item.title,
                                subtitle: item.lastTalkedAt.map {
                                    "最終 \(AnalyticsStyle.dateFormatter.string(from: $0))"
                                } ?? "未トーク",
                                trailing: "\(item.talkCount)回"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .analyticsCardStyle()
    }
}

private struct AnalyticsDormantCard: View {
    let items: [EpisodeDormantItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AnalyticsCardHeader(
                icon: "moon.fill",
                iconFill: Color(hex: "334155"),
                title: "話していないエピソード"
            )

            if items.isEmpty {
                AnalyticsEmptyLabel(text: "データがありません")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items) { item in
                        let subtitle = item.lastTalkedAt.map {
                            "最終 \(AnalyticsStyle.dateFormatter.string(from: $0))"
                        } ?? "未トーク"

                        NavigationLink(value: item.episodeID) {
                            AnalyticsEpisodeRow(
                                title: item.title,
                                subtitle: subtitle,
                                trailing: "\(item.talkCount)回"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .analyticsCardStyle()
    }
}

private struct AnalyticsStrongCard: View {
    let items: [EpisodeHitRateItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AnalyticsCardHeader(
                icon: "flame.fill",
                iconFill: Color(hex: "B91C1C"),
                title: "ウケ率ランキング（3回以上）"
            )

            if items.isEmpty {
                AnalyticsEmptyLabel(text: "条件を満たすエピソードがありません")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items) { item in
                        NavigationLink(value: item.episodeID) {
                            AnalyticsEpisodeRow(
                                title: item.title,
                                subtitle: item.lastTalkedAt.map {
                                    "最終 \(AnalyticsStyle.dateFormatter.string(from: $0))"
                                } ?? "未トーク",
                                trailing: "\(AnalyticsStyle.percent(item.hitRate)) / \(item.talkCount)回"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .analyticsCardStyle()
    }
}

private struct AnalyticsOverusedCard: View {
    let items: [EpisodeOverusedItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AnalyticsCardHeader(
                icon: "exclamationmark.triangle.fill",
                iconFill: Color(hex: "92400E"),
                title: "最近話しすぎエピソード（30日）"
            )

            if items.isEmpty {
                AnalyticsEmptyLabel(text: "直近30日のトークはありません")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items) { item in
                        NavigationLink(value: item.episodeID) {
                            AnalyticsEpisodeRow(
                                title: item.title,
                                subtitle: item.lastTalkedAt.map {
                                    "最終 \(AnalyticsStyle.dateFormatter.string(from: $0))"
                                } ?? "未トーク",
                                trailing: "\(item.recent30DayTalkCount)回"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .analyticsCardStyle()
    }
}

private struct AnalyticsTagTalkCountCard: View {
    let items: [TagTalkCountItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AnalyticsCardHeader(
                icon: "tag.fill",
                iconFill: Color(hex: "1E293B"),
                title: "タグ別トーク回数"
            )

            if items.isEmpty {
                AnalyticsEmptyLabel(text: "データがありません")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items) { item in
                        AnalyticsTagRow(name: item.tagName, trailing: "\(item.talkCount)回")
                    }
                }
            }
        }
        .analyticsCardStyle()
    }
}

private struct AnalyticsTagHitRateCard: View {
    let items: [TagHitRateItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AnalyticsCardHeader(
                icon: "chart.bar.fill",
                iconFill: Color(hex: "374151"),
                title: "タグ別ウケ率（3回以上）"
            )

            if items.isEmpty {
                AnalyticsEmptyLabel(text: "条件を満たすタグがありません")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items) { item in
                        AnalyticsTagRow(
                            name: item.tagName,
                            trailing: "\(AnalyticsStyle.percent(item.hitRate)) / \(item.talkCount)回"
                        )
                    }
                }
            }
        }
        .analyticsCardStyle()
    }
}

private struct AnalyticsCardHeader: View {
    let icon: String
    let iconFill: Color
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconFill)
                )

            Text(title)
                .font(AnalyticsStyle.cardTitleFont)
                .foregroundColor(AnalyticsStyle.cardText)
        }
    }
}

private struct AnalyticsEpisodeRow: View {
    let title: String
    let subtitle: String
    let trailing: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AnalyticsStyle.rowTitleFont)
                    .foregroundColor(AnalyticsStyle.cardText)
                    .lineLimit(2)

                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AnalyticsStyle.supportingText)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(trailing)
                    .font(AppTypography.metaEmphasis)
                    .foregroundColor(AnalyticsStyle.metricText)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "9CA3AF"))
            }
        }
        .padding(.vertical, 6)
    }
}

private struct AnalyticsTagRow: View {
    let name: String
    let trailing: String

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(AnalyticsStyle.rowTitleFont)
                .foregroundColor(AnalyticsStyle.cardText)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(trailing)
                .font(AppTypography.metaEmphasis)
                .foregroundColor(AnalyticsStyle.metricText)
        }
        .padding(.vertical, 4)
    }
}

private struct AnalyticsEmptyLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppTypography.subtext)
            .foregroundColor(AnalyticsStyle.supportingText)
    }
}

private struct AnalyticsErrorCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分析を表示できません")
                .font(AnalyticsStyle.cardTitleFont)
                .foregroundColor(AnalyticsStyle.cardText)

            Text(message)
                .font(AppTypography.body)
                .foregroundColor(AnalyticsStyle.supportingText)
        }
        .analyticsCardStyle()
    }
}

private enum AnalyticsStyle {
    static let figmaTopInset: CGFloat = 59

    static let titleFont = Font.system(size: 34, weight: .bold)
    static let descriptionFont = Font.system(size: 14, weight: .regular)
    static let cardTitleFont = Font.system(size: 20, weight: .semibold)
    static let rowTitleFont = AppTypography.body
    static let bigCountFont = Font.system(size: 54, weight: .bold)

    static let titleText = Color(hex: "101828")
    static let descriptionText = Color(hex: "4A5565")
    static let cardText = Color(hex: "101828")
    static let sectionTitle = Color(hex: "334155")
    static let supportingText = Color(hex: "6A7282")
    static let metricText = Color(hex: "334155")
    static let accentRed = Color(hex: "DC2626")
    static let accentBlue = Color(hex: "1D4ED8")

    static let cardFill = Color.white
    static let cardShadow = Color.black.opacity(0.09)

    static let background = LinearGradient(
        colors: [
            Color(hex: "FCD4D5"),
            Color(hex: "FEE4D9"),
            Color(hex: "FFF3E8")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    static func percent(_ ratio: Double) -> String {
        let value = (ratio * 100).rounded()
        return "\(Int(value))%"
    }
}

private extension View {
    func analyticsCardStyle() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AnalyticsStyle.cardFill)
                    .shadow(color: AnalyticsStyle.cardShadow, radius: 6, x: 0, y: 2)
            )
    }
}

struct AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { AnalyticsView() }
    }
}
