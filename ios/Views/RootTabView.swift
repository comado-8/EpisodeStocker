import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "list.bullet") }
            TagListView()
                .tabItem { Label("タグ", systemImage: "tag") }
            AnalyticsView()
                .tabItem { Label("分析", systemImage: "chart.pie") }
            SettingsView()
                .tabItem { Label("設定", systemImage: "gear") }
        }
    }
}

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View { RootTabView().environmentObject(EpisodeStore()) }
}
