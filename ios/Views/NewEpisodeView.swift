import SwiftUI

struct NewEpisodeView: View {
    @EnvironmentObject var store: EpisodeStore
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var body: String = ""
    @State private var isUnpublished = true

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("タイトル")) {
                    TextField("何が起きた？", text: $title)
                }
                Section(header: Text("本文")) {
                    TextField("詳細 (任意)", text: $body, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                Section {
                    Toggle("未公開", isOn: $isUnpublished)
                }
            }
            .navigationTitle("新規エピソード")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private func save() {
        store.addEpisode(title: title, body: body.isEmpty ? nil : body, status: isUnpublished ? .unpublished : .published)
        dismiss()
    }
}

struct NewEpisodeView_Previews: PreviewProvider {
    static var previews: some View {
        NewEpisodeView().environmentObject(EpisodeStore())
    }
}
