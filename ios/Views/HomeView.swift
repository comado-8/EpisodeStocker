import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: EpisodeStore
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.episodes) { episode in
                    NavigationLink(value: episode.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(episode.title).font(.headline)
                            Text(episode.body ?? "本文なし").font(.subheadline).foregroundColor(.secondary)
                            StatusBadge(status: episode.status)
                        }
                    }
                }
            }
            .navigationTitle("エピソード")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNew = true
                    } label {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNew) {
                NewEpisodeView()
                    .environmentObject(store)
            }
            .navigationDestination(for: UUID.self) { id in
                if let ep = store.episode(id: id) {
                    EpisodeDetailView(episode: ep)
                }
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView().environmentObject(EpisodeStore())
    }
}
