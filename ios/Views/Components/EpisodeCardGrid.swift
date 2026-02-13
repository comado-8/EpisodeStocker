import SwiftUI
import UIKit

struct EpisodeCardGrid: View {
    let title: String
    let tag: String
    let bodyText: String
    let width: CGFloat
    let borderColor: Color
    let showsSelection: Bool
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: HomeStyle.gridCardBodySpacing) {
            ZStack {
                HomeStyle.cardImagePlaceholder
                EpisodeGridThumbnailView()
                    .padding(12)
            }
            .frame(height: HomeStyle.gridCardImageHeight)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: HomeStyle.gridCardTextSpacing) {
                Text(title)
                    .font(HomeFont.bodyLarge())
                    .foregroundColor(HomeStyle.cardTitle)

                Text(tag)
                    .font(HomeFont.titleMedium())
                    .foregroundColor(HomeStyle.cardTitle)

                Text(bodyText)
                    .font(HomeFont.bodyMedium())
                    .foregroundColor(HomeStyle.cardBody)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(HomeStyle.gridCardPadding)
        .frame(width: width, height: HomeStyle.gridCardHeight, alignment: .topLeading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: HomeStyle.gridCardCornerRadius)
                .stroke(borderColor, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            if showsSelection {
                EpisodeSelectionIndicator(isSelected: isSelected)
                    .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: HomeStyle.gridCardCornerRadius))
    }
}

private struct EpisodeGridThumbnailView: View {
    var body: some View {
        if let image = UIImage.namedFromBundle("home_card_thumbnail", ext: "png") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .opacity(0.2)
        } else {
            Image(systemName: "photo")
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

struct EpisodeCardGrid_Previews: PreviewProvider {
    static var previews: some View {
        EpisodeCardGrid(
            title: "Title",
            tag: "#Tag",
            bodyText: "Body text.",
            width: HomeStyle.gridCardWidth,
            borderColor: HomeStyle.cardBorder,
            showsSelection: true,
            isSelected: true
        )
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
