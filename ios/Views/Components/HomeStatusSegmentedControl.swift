import SwiftUI

enum HomeStatusFilter: String, CaseIterable {
    case ok = "解禁OK"
    case locked = "解禁前"
    case all = "全て"
}

struct HomeStatusSegmentedControl: View {
    @Binding var selection: HomeStatusFilter
    let width: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            ForEach(HomeStatusFilter.allCases, id: \.self) { item in
                Button {
                    selection = item
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: iconName(for: item))
                            .font(.system(size: 14, weight: .semibold))
                        Text(item.rawValue)
                            .font(AppTypography.bodyEmphasis)
                            .tracking(0.1)
                    }
                    .foregroundColor(selection == item ? selectedText(for: item) : HomeStyle.segmentText)
                        .frame(maxWidth: .infinity)
                        .frame(height: HomeStyle.segmentedItemHeight)
                        .background(selection == item ? selectedFill(for: item) : Color.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .frame(width: width, height: HomeStyle.statusRowHeight)
        .background(Color.white)
        .overlay(
            Capsule()
                .stroke(HomeStyle.outline, lineWidth: 1)
        )
    }
}

private extension HomeStatusSegmentedControl {
    func iconName(for item: HomeStatusFilter) -> String {
        switch item {
        case .ok:
            return "circle"
        case .locked:
            return "xmark"
        case .all:
            return "line.3.horizontal"
        }
    }

    func selectedFill(for item: HomeStatusFilter) -> Color {
        switch item {
        case .all:
            return HomeStyle.searchFill
        case .locked:
            return HomeStyle.lockedAccent
        case .ok:
            return HomeStyle.segmentSelectedFill
        }
    }

    func selectedText(for item: HomeStatusFilter) -> Color {
        switch item {
        case .ok:
            return HomeStyle.statusOkSelectedText
        case .locked:
            return HomeStyle.statusLockedSelectedText
        case .all:
            return HomeStyle.segmentSelectedText
        }
    }
}

struct HomeStatusSegmentedControl_Previews: PreviewProvider {
    static var previews: some View {
        HomeStatusSegmentedControl(selection: .constant(.ok), width: HomeStyle.segmentedControlWidth)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
