import SwiftData
import SwiftUI

struct TagDetailView: View {
  @EnvironmentObject private var store: EpisodeStore

  let tagID: UUID
  let tagName: String

  @Query(
    filter: #Predicate<Episode> { $0.isSoftDeleted == false },
    sort: [SortDescriptor(\Episode.createdAt, order: .reverse)]
  )
  private var episodes: [Episode]

  @State private var presentedEpisode: PresentedEpisode?

  private var taggedEpisodes: [Episode] {
    episodes.filter { episode in
      episode.tags.contains { tag in
        tag.id == tagID
      }
    }
  }

  private var hasEpisodes: Bool {
    taggedEpisodes.isEmpty == false
  }

  private var episodeCountText: String {
    "\(taggedEpisodes.count)件のエピソード"
  }

  var body: some View {
    GeometryReader { proxy in
      let contentWidth = HomeStyle.contentWidth(for: proxy.size.width)

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text(episodeCountText)
            .font(HomeFont.bodyMedium())
            .foregroundColor(HomeStyle.subtitle)
            .frame(width: contentWidth, alignment: .leading)

          if hasEpisodes {
            LazyVStack(spacing: HomeStyle.listSpacing) {
              ForEach(taggedEpisodes, id: \.id) { episode in
                TagDetailEpisodeRow(
                  episode: episode,
                  width: contentWidth,
                  onTap: {
                    presentedEpisode = PresentedEpisode(id: episode.id)
                  }
                )
              }
            }
            .frame(width: contentWidth)
          } else {
            Text("このタグに紐づくエピソードはありません")
              .font(HomeFont.bodyMedium())
              .foregroundColor(HomeStyle.subtitle)
              .frame(width: contentWidth, alignment: .center)
              .padding(.top, 40)
          }
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
      }
      .background(HomeStyle.background.ignoresSafeArea())
    }
    .navigationTitle(tagName)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .navigationBar)
    .sheet(item: $presentedEpisode) { item in
      EpisodeDetailContainer(episodeId: item.id)
        .environmentObject(store)
    }
  }
}

private struct PresentedEpisode: Identifiable {
  let id: UUID
}

private struct TagDetailEpisodeRow: View {
  let episode: Episode
  let width: CGFloat
  let onTap: () -> Void

  private var borderColor: Color {
    episode.isUnlocked ? HomeStyle.cardBorder : HomeStyle.lockedCardBorder
  }

  var body: some View {
    Button(action: onTap) {
      EpisodeCardRow(
        title: episode.title,
        subtitle: episode.body ?? "",
        talkedCount: episode.talkedCount,
        latestTalkedAt: episode.latestTalkedAt,
        date: episode.date,
        isUnlocked: episode.isUnlocked,
        width: width,
        borderColor: borderColor,
        showsSelection: false,
        isSelected: false
      )
    }
    .buttonStyle(.plain)
  }
}

struct TagDetailView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      TagDetailView(tagID: UUID(), tagName: "#SNS")
        .environmentObject(EpisodeStore())
    }
  }
}
