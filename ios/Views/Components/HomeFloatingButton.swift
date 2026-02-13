import SwiftUI

struct HomeFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: HomeStyle.fabSize, height: HomeStyle.fabSize)
                .background(HomeStyle.fabRed)
                .clipShape(RoundedRectangle(cornerRadius: HomeStyle.fabCornerRadius, style: .continuous))
                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
