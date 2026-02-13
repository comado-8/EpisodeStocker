import SwiftUI

struct TagListView: View {
    @EnvironmentObject var store: EpisodeStore

    var body: some View {
        NavigationStack {
            List(store.tags) { tag in
                HStack {
                    Text("#" + tag.name)
                    Spacer()
                    Text("\(tag.usageCount)")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("タグ")
        }
    }
}

struct TagListView_Previews: PreviewProvider {
    static var previews: some View {
        TagListView().environmentObject(EpisodeStore())
    }
}
