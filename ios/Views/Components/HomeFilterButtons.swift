import SwiftUI

enum HomeLayoutMode: String, CaseIterable {
    case list
    case grid
}

struct HomeFilterButtons: View {
    @Binding var selection: HomeLayoutMode

    var body: some View {
        HStack(spacing: 0) {
            layoutButton(mode: .list, systemName: "line.3.horizontal")
            Rectangle()
                .fill(HomeStyle.outline)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
            layoutButton(mode: .grid, systemName: "square.grid.2x2")
        }
        .frame(width: HomeStyle.filterButtonsWidth, height: HomeStyle.statusRowHeight)
        .background(Color.white)
        .overlay(Capsule().stroke(HomeStyle.outline, lineWidth: 1))
        .clipShape(Capsule())
    }

    private func layoutButton(mode: HomeLayoutMode, systemName: String) -> some View {
        Button {
            selection = mode
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(selection == mode ? HomeStyle.segmentSelectedText : HomeStyle.segmentText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(selection == mode ? HomeStyle.segmentSelectedFill : Color.white)
        }
        .buttonStyle(.plain)
    }
}
