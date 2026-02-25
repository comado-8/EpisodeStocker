import SwiftUI

struct EpisodeCardRow: View {
    let title: String
    let subtitle: String
    let date: Date
    let isUnlocked: Bool
    let width: CGFloat
    let borderColor: Color
    let showsSelection: Bool
    let isSelected: Bool

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

                VStack(alignment: .leading, spacing: 6) {
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
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
