import SwiftUI

struct HomeSearchSuggestionPanel: View {
    let width: CGFloat
    let items: [HomeSearchSuggestionItem]
    let onSelect: (HomeSearchSuggestionItem) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: item.symbolName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(HomeStyle.searchSuggestionIcon)
                                .frame(width: 18, height: 18)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(AppTypography.subtextEmphasis)
                                    .foregroundColor(HomeStyle.searchSuggestionTitle)
                                    .lineLimit(1)
                                Text(item.subtitle)
                                    .font(AppTypography.subtext)
                                    .foregroundColor(HomeStyle.searchSuggestionSubtitle)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: HomeStyle.searchSuggestionRowHeight,
                            alignment: .leading
                        )
                        .contentShape(Rectangle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        Rectangle()
                            .fill(HomeStyle.searchSuggestionDivider)
                            .frame(height: 1)
                            .padding(.leading, 40)
                    }
                }
            }
            .frame(width: width, alignment: .leading)
            .background(HomeStyle.background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HomeStyle.searchSuggestionBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
    }
}

struct HomeSearchSuggestionPanel_Previews: PreviewProvider {
    static var previews: some View {
        HomeSearchSuggestionPanel(
            width: 360,
            items: [
                HomeSearchSuggestionItem(kind: .value(field: .tag, value: "仕事")),
                HomeSearchSuggestionItem(kind: .value(field: .person, value: "佐藤さん"))
            ],
            onSelect: { _ in }
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
