import SwiftUI

struct EpisodeCardReactionCounts: Equatable {
    let hit: Int
    let soSo: Int
    let shelved: Int
}

struct EpisodeCardBadgeModel: Equatable {
    let talkedCountText: String
    let latestTalkedAtText: String
    let showsReactionBadge: Bool
    let reactionCounts: EpisodeCardReactionCounts

    static func make(
        talkedCount: Int,
        latestTalkedAt: Date?,
        reactionCounts: EpisodeCardReactionCounts
    ) -> EpisodeCardBadgeModel {
        let latestTalkedAtText: String
        if let latestTalkedAt {
            latestTalkedAtText = dateFormatter.string(from: latestTalkedAt)
        } else {
            latestTalkedAtText = "-"
        }

        return EpisodeCardBadgeModel(
            talkedCountText: "\(max(0, talkedCount))回",
            latestTalkedAtText: latestTalkedAtText,
            showsReactionBadge: talkedCount > 0,
            reactionCounts: reactionCounts
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
}

struct EpisodeCardRow: View {
    let title: String
    let subtitle: String
    let talkedCount: Int
    let latestTalkedAt: Date?
    let reactionCounts: EpisodeCardReactionCounts
    let date: Date
    let isUnlocked: Bool
    let width: CGFloat
    let borderColor: Color
    let showsSelection: Bool
    let isSelected: Bool

    private var badgeModel: EpisodeCardBadgeModel {
        EpisodeCardBadgeModel.make(
            talkedCount: talkedCount,
            latestTalkedAt: latestTalkedAt,
            reactionCounts: reactionCounts
        )
    }

    var body: some View {
        let cardWidth = showsSelection
            ? max(0, width - HomeStyle.selectionIndicatorSize - HomeStyle.selectionIndicatorSpacing)
            : width

        HStack(spacing: HomeStyle.selectionIndicatorSpacing) {
            if showsSelection {
                EpisodeSelectionIndicator(isSelected: isSelected)
            }

            HStack(spacing: HomeStyle.cardContentSpacing) {
                VStack(spacing: 0) {
                    Text(Self.yearFormatter.string(from: date))
                        .font(HomeFont.cardDateYear())
                        .foregroundColor(dateTextColor)

                    Text(Self.monthDayFormatter.string(from: date))
                        .font(HomeFont.cardDateDay())
                        .tracking(0.3)
                        .foregroundColor(dateTextColor)
                }
                .frame(width: HomeStyle.dateBadgeSize, height: HomeStyle.dateBadgeSize)
                .background(dateBadgeFill)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: HomeStyle.cardMetaVerticalSpacing) {
                    Text(title)
                        .font(AppTypography.sectionTitle)
                        .tracking(0.15)
                        .foregroundColor(HomeStyle.textPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(AppTypography.subtext)
                        .tracking(0.25)
                        .foregroundColor(HomeStyle.subtitle)
                        .lineLimit(1)

                    Rectangle()
                        .fill(HomeStyle.cardMetaDivider)
                        .frame(height: HomeStyle.cardMetaDividerHeight)

                    HStack(spacing: HomeStyle.cardMetaBadgeSpacing) {
                        metaBadge(iconSystemName: "person.wave.2", text: badgeModel.talkedCountText)
                        metaBadge(iconSystemName: "clock.arrow.circlepath", text: badgeModel.latestTalkedAtText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, HomeStyle.cardHorizontalPadding)
            .padding(.top, HomeStyle.cardContentTopPadding)
            .padding(.bottom, HomeStyle.cardContentBottomPadding)
            .frame(width: cardWidth, height: HomeStyle.cardHeight)
            .background(cardBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: HomeStyle.cardCornerRadius)
                    .stroke(borderColor, lineWidth: HomeStyle.listCardBorderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: HomeStyle.cardCornerRadius))
        }
        .frame(width: width, height: HomeStyle.cardHeight, alignment: .leading)
    }

    @ViewBuilder
    private func metaBadge(iconSystemName: String, text: String) -> some View {
        HStack(spacing: HomeStyle.cardMetaBadgeInnerSpacing) {
            Image(systemName: iconSystemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(HomeStyle.cardMetaBadgeIcon)

            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundColor(HomeStyle.cardMetaBadgeText)
        }
        .font(AppTypography.metaEmphasis)
        .padding(.horizontal, HomeStyle.cardMetaBadgeHorizontalPadding)
        .frame(height: HomeStyle.cardMetaBadgeHeight)
        .background(HomeStyle.cardMetaBadgeFill)
        .clipShape(Capsule())
    }

    private var dateBadgeFill: Color {
        isUnlocked ? HomeStyle.segmentSelectedFill : HomeStyle.lockedAccent
    }

    private var cardBackgroundColor: Color {
        if showsSelection && isSelected {
            return HomeStyle.selectionCardBackground
        }
        return isUnlocked ? HomeStyle.cardBackgroundUnlocked : HomeStyle.cardBackgroundLocked
    }

    private var dateTextColor: Color {
        isUnlocked ? HomeStyle.dateTextUnlocked : HomeStyle.dateTextLocked
    }

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return formatter
    }()
}

struct EpisodeCardRow_Previews: PreviewProvider {
    static var previews: some View {
        EpisodeCardRow(
            title: "Header",
            subtitle: "Subhead",
            talkedCount: 3,
            latestTalkedAt: Date(),
            reactionCounts: EpisodeCardReactionCounts(hit: 1, soSo: 1, shelved: 1),
            date: Date(),
            isUnlocked: true,
            width: 360,
            borderColor: HomeStyle.cardBorder,
            showsSelection: true,
            isSelected: true
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
