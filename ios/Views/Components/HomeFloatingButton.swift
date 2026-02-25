import SwiftUI

struct HomeFloatingButton: View {
    enum IconStyle {
        case plus
        case tagPlus
    }

    var iconStyle: IconStyle = .plus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            iconView
                .frame(width: HomeStyle.fabSize, height: HomeStyle.fabSize)
                .background(HomeStyle.fabRed)
                .clipShape(RoundedRectangle(cornerRadius: HomeStyle.fabCornerRadius, style: .continuous))
                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var iconView: some View {
        switch iconStyle {
        case .plus:
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
        case .tagPlus:
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "tag")
                    .font(.system(size: 21, weight: .semibold))
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .black))
                    .offset(x: 6, y: 6)
            }
            .symbolRenderingMode(.monochrome)
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .offset(x: -3, y: -3)
        }
    }
}
