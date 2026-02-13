import SwiftUI

struct AnalyticsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("分析 (サブスク)").font(.title3).bold()
            Text("タグ/カテゴリ別の利用数や未公開率のグラフをここに表示する予定です。").multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .navigationTitle("分析")
    }
}

struct AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { AnalyticsView() }
    }
}
