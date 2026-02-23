import SwiftUI

struct HomeSearchFilterChipRow: View {
    let width: CGFloat
    let tokens: [HomeSearchFilterToken]
    let onRemoveToken: (HomeSearchFilterToken) -> Void

    var body: some View {
        if !tokens.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tokens) { token in
                        HStack(spacing: 6) {
                            Text(token.displayText)
                                .lineLimit(1)
                            Button {
                                onRemoveToken(token)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(HomeStyle.searchChipText)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(HomeStyle.searchChipFill)
                        .overlay(
                            Capsule()
                                .stroke(HomeStyle.searchChipBorder, lineWidth: 1)
                        )
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(width: width, alignment: .leading)
        }
    }
}

struct HomeSearchFilterChipRow_Previews: PreviewProvider {
    static var previews: some View {
        HomeSearchFilterChipRow(
            width: 360,
            tokens: [
                HomeSearchFilterToken(field: .tag, value: "仕事")!,
                HomeSearchFilterToken(field: .person, value: "田中")!
            ],
            onRemoveToken: { _ in }
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
