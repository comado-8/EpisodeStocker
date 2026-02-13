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
                    Text(item.rawValue)
                        .font(HomeFont.labelLarge())
                        .tracking(0.1)
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
    func selectedFill(for item: HomeStatusFilter) -> Color {
        switch item {
        case .locked:
            return HomeStyle.lockedAccent
        default:
            return HomeStyle.segmentSelectedFill
        }
    }

    func selectedText(for item: HomeStatusFilter) -> Color {
        switch item {
        case .locked:
            return HomeStyle.lockedSegmentText
        default:
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
