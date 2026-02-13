import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("サブスクリプション")) {
                    Label("プラン/更新日/試用残日数", systemImage: "creditcard")
                }
                Section(header: Text("バックアップ")) {
                    Label("クラウド/手動バックアップ", systemImage: "icloud")
                }
                Section(header: Text("セキュリティ")) {
                    Label("パスコード/生体認証", systemImage: "lock")
                }
                Section(header: Text("表示")) {
                    Label("テーマ・フォントサイズ・リスト/カード表示", systemImage: "textformat.size")
                }
                Section(header: Text("法務")) {
                    Label("利用規約・プライバシー", systemImage: "doc.text")
                }
            }
            .navigationTitle("設定")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
