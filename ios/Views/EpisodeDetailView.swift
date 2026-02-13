import SwiftUI

struct EpisodeDetailView: View {
    let episode: Episode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(episode.title)
                        .font(.title2).bold()
                    Spacer()
                    StatusBadge(status: episode.status)
                }
                if let body = episode.body, !body.isEmpty {
                    Text(body).font(.body)
                } else {
                    Text("本文なし").foregroundColor(.secondary)
                }
                Divider()
                Text("作成日: \(formatted(episode.createdAt))")
                    .font(.caption).foregroundColor(.secondary)
                Text("更新日: \(formatted(episode.updatedAt))")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("詳細")
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().hour().minute())
    }
}

struct EpisodeDetailView_Previews: PreviewProvider {
    static var previews: some View {
        if let sample = EpisodeStore().episodes.first {
            NavigationStack { EpisodeDetailView(episode: sample) }
        }
    }
}
