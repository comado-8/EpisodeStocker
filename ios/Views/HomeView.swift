import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Episode> { $0.isSoftDeleted == false },
        sort: [SortDescriptor(\Episode.createdAt, order: .reverse)]
    )
    private var episodes: [Episode]
    @State private var query = ""
    @State private var statusFilter: HomeStatusFilter = .ok
    @State private var isSearchCommitted = false
    @State private var isSelectionMode = false
    @State private var selectedEpisodeIDs: Set<UUID> = []
    @State private var showsDeleteAlert = false
    @State private var suppressNextNavigation = false
    @FocusState private var isSearchFocused: Bool

    private var filteredEpisodes: [Episode] {
        episodes.filter { episode in
            let matchesQuery = query.isEmpty || episode.title.localizedCaseInsensitiveContains(query) || (episode.body ?? "").localizedCaseInsensitiveContains(query)
            let matchesStatus: Bool
            switch statusFilter {
            case .ok:
                matchesStatus = episode.isUnlocked
            case .locked:
                matchesStatus = !episode.isUnlocked
            case .all:
                matchesStatus = true
            }
            return matchesQuery && matchesStatus
        }
    }

    private var filteredEpisodeIDs: [UUID] {
        filteredEpisodes.map(\.id)
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = HomeStyle.contentWidth(for: proxy.size.width)
            let segmentedWidth = contentWidth
            let bottomInset = baseSafeAreaBottom()
            let topPadding = max(0, HomeStyle.figmaTopInset - proxy.safeAreaInsets.top)
            let fabBottomPadding = HomeStyle.tabBarHeight + HomeStyle.fabBottomOffset
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let isSearchEmpty = !trimmedQuery.isEmpty && filteredEpisodes.isEmpty && isSearchCommitted
            let showsSearchBack = isSearchCommitted && !trimmedQuery.isEmpty && !isSearchFocused
            let isShowingSearchResults = isSearchCommitted && !trimmedQuery.isEmpty
            let visibleEpisodes = filteredEpisodes

            ZStack(alignment: .bottomTrailing) {
                HomeStyle.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: HomeStyle.sectionSpacing) {
                        HomeSearchBarView(text: $query, width: contentWidth, isFocused: $isSearchFocused, showsBack: showsSearchBack) {
                            let committedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                            isSearchFocused = false
                            isSearchCommitted = !committedQuery.isEmpty
                            hideKeyboard()
                        } onCancel: {
                            query = ""
                            isSearchFocused = false
                            isSearchCommitted = false
                            hideKeyboard()
                        }
                        .onChange(of: query) { _, newValue in
                            let currentQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if currentQuery.isEmpty {
                                isSearchCommitted = false
                            } else if isSearchFocused {
                                isSearchCommitted = false
                            }
                        }
                        .onChange(of: isSearchFocused) { _, focused in
                            if focused {
                                isSearchCommitted = false
                            } else {
                                let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                                isSearchCommitted = !currentQuery.isEmpty
                            }
                        }

                        VStack(spacing: HomeStyle.sectionSpacing) {
                            Rectangle()
                                .fill(HomeStyle.outline)
                                .frame(width: contentWidth, height: HomeStyle.dividerHeight)

                            if isSelectionMode {
                                HomeSelectionStatusRow(
                                    count: selectedEpisodeIDs.count,
                                    onCancel: { endSelection() },
                                    onDelete: { showsDeleteAlert = selectedEpisodeIDs.isEmpty == false }
                                )
                                .frame(width: contentWidth, height: HomeStyle.selectionStatusRowHeight)
                            } else {
                                HomeStatusSegmentedControl(selection: $statusFilter, width: segmentedWidth)
                                    .frame(width: contentWidth, height: HomeStyle.statusRowHeight)
                            }

                            if isShowingSearchResults {
                                HStack(spacing: 8) {
                                    Text("検索結果")
                                        .font(HomeFont.labelLarge())
                                        .foregroundColor(HomeStyle.segmentSelectedText)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(HomeStyle.segmentSelectedFill)
                                        .clipShape(Capsule())

                                    Text("“\(trimmedQuery)”")
                                        .font(HomeFont.bodyMedium())
                                        .foregroundColor(HomeStyle.subtitle)
                                        .lineLimit(1)

                                    Spacer(minLength: 0)

                                    Text("\(filteredEpisodes.count)件")
                                        .font(HomeFont.bodyMedium())
                                        .foregroundColor(HomeStyle.subtitle)
                                }
                                .frame(width: contentWidth)
                            }

                            if isSearchEmpty {
                                HomeSearchEmptyView(contentWidth: contentWidth)
                            } else {
                                LazyVStack(spacing: HomeStyle.listSpacing) {
                                    ForEach(visibleEpisodes, id: \.id) { episode in
                                        episodeListRow(episode: episode, width: contentWidth)
                                    }
                                }
                                .padding(.top, HomeStyle.listSpacing - HomeStyle.sectionSpacing)
                            }
                        }
                        .onTapGesture {
                            if isSearchFocused {
                                isSearchFocused = false
                                hideKeyboard()
                            }
                        }
                    }
                    .padding(.top, topPadding)
                    .padding(.bottom, HomeStyle.tabBarHeight + 16 + bottomInset)
                    .frame(maxWidth: .infinity)
                }

                if !isSelectionMode {
                    HomeFloatingButton {
                        router.push(.newEpisode)
                    }
                    .padding(.trailing, max(HomeStyle.fabTrailing, HomeStyle.horizontalPadding))
                    .padding(.bottom, fabBottomPadding)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onChange(of: filteredEpisodeIDs) { _, newValue in
            let visible = Set(newValue)
            selectedEpisodeIDs = selectedEpisodeIDs.intersection(visible)
            if selectedEpisodeIDs.isEmpty {
                isSelectionMode = false
            }
        }
        .alert("選択したエピソードを削除しますか？", isPresented: $showsDeleteAlert) {
            Button("削除", role: .destructive) {
                deleteSelectedEpisodes()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(selectedEpisodeIDs.count)件を削除します。")
        }
    }
}

private extension HomeView {
    func borderColor(for episode: Episode) -> Color {
        episode.isUnlocked ? HomeStyle.cardBorder : HomeStyle.lockedCardBorder
    }

    func baseSafeAreaBottom() -> CGFloat {
        #if canImport(UIKit)
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        if let window = windowScene?.windows.first(where: { $0.isKeyWindow }) {
            return window.safeAreaInsets.bottom
        }
        #endif
        return 0
    }

    @ViewBuilder
    func episodeListRow(episode: Episode, width: CGFloat) -> some View {
        let isSelected = selectedEpisodeIDs.contains(episode.id)
        let rowView = EpisodeCardRow(
            title: episode.title,
            subtitle: episode.body ?? "Subhead",
            date: episode.date,
            isUnlocked: episode.isUnlocked,
            width: width,
            borderColor: borderColor(for: episode),
            showsSelection: isSelectionMode,
            isSelected: isSelected
        )

        if isSelectionMode {
            rowView
                .contentShape(Rectangle())
                .onTapGesture { toggleSelection(episode.id) }
        } else {
            rowView
                .contentShape(RoundedRectangle(cornerRadius: HomeStyle.cardCornerRadius, style: .continuous))
                .onTapGesture {
                    if suppressNextNavigation {
                        suppressNextNavigation = false
                        return
                    }
                    router.push(.episodeDetail(episode.id))
            }
            .onLongPressGesture(minimumDuration: 0.3) {
                beginSelection(with: episode.id)
            }
        }
    }

    func beginSelection(with id: UUID) {
        suppressNextNavigation = true
        if !isSelectionMode {
            isSelectionMode = true
        }
        selectedEpisodeIDs.insert(id)
    }

    func toggleSelection(_ id: UUID) {
        if selectedEpisodeIDs.contains(id) {
            selectedEpisodeIDs.remove(id)
        } else {
            selectedEpisodeIDs.insert(id)
        }

        if selectedEpisodeIDs.isEmpty {
            suppressNextNavigation = false
            isSelectionMode = false
        }
    }

    func endSelection() {
        selectedEpisodeIDs.removeAll()
        suppressNextNavigation = false
        isSelectionMode = false
    }

    func deleteSelectedEpisodes() {
        let ids = Array(selectedEpisodeIDs)
        for id in ids {
            guard let episode = episodes.first(where: { $0.id == id }) else { continue }
            modelContext.softDeleteEpisode(episode)
        }
        endSelection()
    }
}

private extension View {
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AppRouter())
    }
}

private struct HomeSelectionStatusRow: View {
    let count: Int
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button("キャンセル") {
                onCancel()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(HomeStyle.selectionCancelText)

            Spacer(minLength: 0)

            Text("\(count)件選択")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(HomeStyle.selectionCountText)

            Spacer(minLength: 0)

            Button {
                onDelete()
            } label: {
                Text("削除")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(HomeStyle.selectionDeleteText)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(HomeStyle.selectionDeleteFill)
                    )
            }
            .disabled(count == 0)
            .opacity(count == 0 ? 0.5 : 1)
        }
        .padding(.horizontal, HomeStyle.selectionStatusRowHorizontalPadding)
        .frame(height: HomeStyle.selectionStatusRowHeight)
        .background(
            Capsule()
                .fill(HomeStyle.selectionStatusRowFill)
                .overlay(
                    Capsule()
                        .stroke(HomeStyle.selectionStatusRowBorder, lineWidth: 1)
                )
        )
    }
}

private struct HomeSearchEmptyView: View {
    let contentWidth: CGFloat

    var body: some View {
        VStack(spacing: HomeStyle.emptyStateSpacing) {
            ZStack {
                Circle()
                    .fill(HomeStyle.emptyStateBackground)
                    .frame(width: HomeStyle.emptyStateCircleSize, height: HomeStyle.emptyStateCircleSize)
                Image("EmptySearchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: HomeStyle.emptyStateIconSize, height: HomeStyle.emptyStateIconSize)
            }

            Text("異なるワードで検索してみてください")
                .font(HomeFont.emptyStateTitle())
                .foregroundColor(HomeStyle.emptyStateText)
                .multilineTextAlignment(.center)
                .frame(width: min(contentWidth, HomeStyle.emptyStateTextWidth))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, HomeStyle.emptyStateTopPadding)
    }
}
