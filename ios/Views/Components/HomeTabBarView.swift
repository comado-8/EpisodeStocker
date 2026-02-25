import SwiftUI

enum RootTab: String, CaseIterable {
    case home
    case tags
    case analytics
    case settings

    var title: String {
        switch self {
        case .home: return "Home"
        case .tags: return "Tag"
        case .analytics: return "Analytics"
        case .settings: return "Setting"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "star.fill"
        case .tags: return "tag.fill"
        case .analytics: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

struct HomeTabBarView: View {
    @Binding var selection: RootTab
    var onTabTap: ((RootTab) -> Void)? = nil

    var body: some View {
        HStack {
            ForEach(RootTab.allCases, id: \.self) { tab in
                Button {
                    if let onTabTap {
                        onTabTap(tab)
                    } else {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                        Text(tab.title)
                            .font(HomeFont.tabLabel())
                            .tracking(0.1)
                    }
                    .foregroundColor(selection == tab ? HomeStyle.tabSelected : HomeStyle.tabUnselected)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: HomeStyle.tabBarHeight)
        .padding(.horizontal, 16)
        .background(
            VStack(spacing: 0) {
                Rectangle().fill(HomeStyle.outline).frame(height: 1)
                Color.white
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }
}
