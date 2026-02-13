import SwiftUI
import UIKit

struct EpisodeCardRow: View {
    let title: String
    let subtitle: String
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

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(HomeFont.titleMedium())
                        .tracking(0.15)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(HomeFont.bodyMedium())
                        .tracking(0.25)
                        .foregroundColor(HomeStyle.subtitle)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    HomeStyle.cardAccent
                    EpisodeThumbnailView()
                        .padding(10)
                }
                .frame(width: HomeStyle.cardAccentWidth)
            }
            .frame(width: cardWidth, height: HomeStyle.cardHeight)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: HomeStyle.cardCornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: HomeStyle.cardCornerRadius))
        }
        .frame(width: width, height: HomeStyle.cardHeight, alignment: .leading)
    }
}

private struct EpisodeThumbnailView: View {
    var body: some View {
        if let image = UIImage.namedFromBundle("home_card_thumbnail", ext: "png") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .opacity(0.75)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "heart.fill")
                Image(systemName: "star.fill")
                Image(systemName: "square.fill")
            }
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.75))
        }
    }
}

struct EpisodeCardRow_Previews: PreviewProvider {
    static var previews: some View {
        EpisodeCardRow(
            title: "Header",
            subtitle: "Subhead",
            width: 360,
            borderColor: HomeStyle.cardBorder,
            showsSelection: true,
            isSelected: true
        )
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
