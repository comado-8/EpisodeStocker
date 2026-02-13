import SwiftUI

struct EpisodeSelectionIndicator: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? HomeStyle.selectionIndicatorFill : Color.clear)
            Circle()
                .stroke(HomeStyle.selectionIndicatorBorder, lineWidth: 1)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(HomeStyle.selectionIndicatorCheck)
            }
        }
        .frame(width: HomeStyle.selectionIndicatorSize, height: HomeStyle.selectionIndicatorSize)
    }
}

struct EpisodeSelectionIndicator_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            EpisodeSelectionIndicator(isSelected: false)
            EpisodeSelectionIndicator(isSelected: true)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
