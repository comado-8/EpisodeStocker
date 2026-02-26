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
    @State private var searchTokens: [HomeSearchFilterToken] = []
    @State private var activeSearchField: HomeSearchField?
    @State private var statusFilter: HomeStatusFilter = .ok
    @State private var sortOption: HomeEpisodeSortOption = .createdAtDescending
    @State private var isSearchCommitted = false
    @State private var showsAdvancedFilterSheet = false
    @State private var advancedFilterDraft = HomeAdvancedFilterDraft()
    @State private var isSelectionMode = false
    @State private var selectedEpisodeIDs: Set<UUID> = []
    @State private var showsDeleteAlert = false
    @State private var suppressNextNavigation = false
    @State private var scrollContentHeight: CGFloat = 0
    @State private var scrollViewportHeight: CGFloat = 0
    @FocusState private var isSearchFocused: Bool

    private var currentSearchState: HomeSearchQueryState {
        HomeSearchQueryState(
            freeText: query,
            tokens: searchTokens,
            activeField: activeSearchField
        )
    }

    private var committedSearchState: HomeSearchQueryState {
        if isSearchCommitted {
            return currentSearchState
        }
        return HomeSearchQueryState()
    }

    private var filteringSearchState: HomeSearchQueryState {
        if isSearchCommitted {
            return currentSearchState
        }

        // While typing free text (not field-input mode), apply incremental filtering.
        if isSearchFocused,
           activeSearchField == nil,
           !currentSearchState.trimmedFreeText.isEmpty
        {
            return HomeSearchQueryState(
                freeText: query,
                tokens: searchTokens,
                activeField: nil
            )
        }

        // Keep token filtering active even before explicit submit.
        if !searchTokens.isEmpty {
            return HomeSearchQueryState(
                freeText: "",
                tokens: searchTokens,
                activeField: nil
            )
        }

        return HomeSearchQueryState()
    }

    private var filteredEpisodes: [Episode] {
        episodes.filter { episode in
            HomeSearchQueryEngine.matches(
                episode: episode,
                statusFilter: statusFilter,
                search: filteringSearchState
            )
        }
    }

    private var filteredEpisodeIDs: [UUID] {
        filteredEpisodes.map(\.id)
    }

    private var isAdvancedFilterEnabled: Bool {
        // Keep this switch for future subscription gating.
        true
    }

    private var hasAdvancedHistoryFilterToken: Bool {
        searchTokens.contains { HomeAdvancedFilterDraft.isHistoryField($0.field) }
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = HomeStyle.contentWidth(for: proxy.size.width)
            let segmentedWidth = contentWidth
            let bottomInset = baseSafeAreaBottom()
            let topPadding = max(0, HomeStyle.figmaTopInset - proxy.safeAreaInsets.top)
            let fabBottomPadding = HomeStyle.tabBarHeight + HomeStyle.fabBottomOffset
            let desiredListBottomPadding = HomeStyle.tabBarHeight + 16 + bottomInset
            let listBottomPadding: CGFloat = scrollContentHeight > (scrollViewportHeight + 1)
                ? desiredListBottomPadding
                : 0
            let committedHasConditions = committedSearchState.hasAnyCondition
            let isSearchEmpty = committedHasConditions && filteredEpisodes.isEmpty && isSearchCommitted
            let showsSearchBack = isSearchCommitted && committedHasConditions && !isSearchFocused
            let isShowingSearchResults = isSearchCommitted && committedHasConditions
            let visibleEpisodes = sortedEpisodes(filteredEpisodes)
            let suggestionItems: [HomeSearchSuggestionItem] = {
                guard isSearchFocused else { return [] }
                return HomeSearchQueryEngine.suggestions(
                    for: currentSearchState,
                    episodes: episodes
                )
            }()

            ZStack(alignment: .bottomTrailing) {
                HomeStyle.background.ignoresSafeArea()

                VStack(spacing: HomeStyle.sectionSpacing) {
                    VStack(spacing: HomeStyle.sectionSpacing) {
                        HomeSearchBarView(
                            text: $query,
                            width: contentWidth,
                            isFocused: $isSearchFocused,
                            showsBack: showsSearchBack,
                            accessory: isAdvancedFilterEnabled
                                ? .advancedFilter(isActive: hasAdvancedHistoryFilterToken)
                                : .legacyMagnifier
                        ) {
                            let committedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let activeSearchField,
                               !committedQuery.isEmpty
                            {
                                appendSearchToken(field: activeSearchField, value: committedQuery)
                                query = ""
                                self.activeSearchField = nil
                            }
                            isSearchFocused = false
                            isSearchCommitted = hasAnySearchCondition()
                            hideKeyboard()
                        } onCancel: {
                            clearSearchConditions()
                            isSearchFocused = false
                            isSearchCommitted = false
                            hideKeyboard()
                        } onClearText: {
                            query = ""
                            if !isSearchFocused {
                                isSearchCommitted = hasAnySearchCondition()
                            }
                        } onAccessoryTap: {
                            guard isAdvancedFilterEnabled else { return }
                            openAdvancedFilterSheet()
                        }
                        .onChange(of: query) { _, _ in
                            if isSearchFocused {
                                // Keep structured search active while user is typing the next token.
                                isSearchCommitted = !searchTokens.isEmpty
                            } else if !hasAnySearchCondition() {
                                isSearchCommitted = false
                            }
                        }
                        .onChange(of: isSearchFocused) { _, focused in
                            if focused {
                                // Keep token-based filtering active while user edits the next query.
                                isSearchCommitted = !searchTokens.isEmpty
                            } else {
                                // Reset one-shot field mode when editing ends.
                                activeSearchField = nil
                                isSearchCommitted = hasAnySearchCondition()
                            }
                        }
                        .onChange(of: searchTokens) { _, _ in
                            if isSearchFocused {
                                isSearchCommitted = !searchTokens.isEmpty
                            } else {
                                isSearchCommitted = hasAnySearchCondition()
                            }
                        }

                        HomeSearchFilterChipRow(
                            width: contentWidth,
                            tokens: searchTokens,
                            onRemoveToken: { token in
                                searchTokens.removeAll { $0 == token }
                            }
                        )

                        if isSearchFocused && !suggestionItems.isEmpty {
                            HomeSearchSuggestionPanel(
                                width: contentWidth,
                                items: suggestionItems,
                                onSelect: applySuggestion
                            )
                        }

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
                            HomeEpisodeSortControl(selection: $sortOption, width: contentWidth)
                        }
                    }
                    .frame(width: contentWidth, alignment: .top)

                    ScrollView {
                        VStack(spacing: HomeStyle.sectionSpacing) {
                            if isShowingSearchResults {
                                HStack(spacing: 8) {
                                    Text("検索結果")
                                        .font(HomeFont.labelLarge())
                                        .foregroundColor(HomeStyle.segmentSelectedText)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(HomeStyle.segmentSelectedFill)
                                        .clipShape(Capsule())

                                    let searchSummaryText = buildSearchSummaryText()
                                    if !searchSummaryText.isEmpty {
                                        Text(searchSummaryText)
                                            .font(HomeFont.bodyMedium())
                                            .foregroundColor(HomeStyle.subtitle)
                                            .lineLimit(1)
                                    }

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
                        .frame(width: contentWidth, alignment: .topLeading)
                        .background(
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: HomeScrollContentHeightPreferenceKey.self,
                                    value: geometry.size.height
                                )
                            }
                        )
                        .padding(.bottom, listBottomPadding)
                    }
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: HomeScrollViewportHeightPreferenceKey.self,
                                value: geometry.size.height
                            )
                        }
                    )
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        if isSearchFocused {
                            isSearchFocused = false
                            hideKeyboard()
                        }
                    },
                    including: .subviews
                )
                .padding(.top, topPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

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
        .onPreferenceChange(HomeScrollContentHeightPreferenceKey.self) { height in
            scrollContentHeight = height
        }
        .onPreferenceChange(HomeScrollViewportHeightPreferenceKey.self) { height in
            scrollViewportHeight = height
        }
        .alert("選択したエピソードを削除しますか？", isPresented: $showsDeleteAlert) {
            Button("削除", role: .destructive) {
                deleteSelectedEpisodes()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(selectedEpisodeIDs.count)件を削除します。")
        }
        .sheet(isPresented: $showsAdvancedFilterSheet) {
            HomeAdvancedFilterSheet(
                draft: $advancedFilterDraft,
                onApply: {
                    applyAdvancedFilterDraft()
                    showsAdvancedFilterSheet = false
                },
                onClear: {
                    clearAdvancedHistoryFilters()
                    showsAdvancedFilterSheet = false
                }
            )
            .presentationDetents([.height(HomeStyle.advancedFilterSheetHeight)])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct HomeScrollContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct HomeScrollViewportHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension HomeView {
    func borderColor(for episode: Episode) -> Color {
        episode.isUnlocked ? HomeStyle.cardBorder : HomeStyle.lockedCardBorder
    }

    func hasAnySearchCondition() -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty || !searchTokens.isEmpty
    }

    func clearSearchConditions() {
        query = ""
        searchTokens.removeAll()
        activeSearchField = nil
        advancedFilterDraft.clearHistoryConditions()
    }

    func appendSearchToken(field: HomeSearchField, value: String) {
        guard let token = HomeSearchFilterToken(field: field, value: value) else { return }
        if !searchTokens.contains(token) {
            searchTokens.append(token)
        }
    }

    func applySuggestion(_ item: HomeSearchSuggestionItem) {
        switch item.kind {
        case .selectField(let field):
            activeSearchField = field
            isSearchCommitted = !searchTokens.isEmpty
        case .value(let field, let value):
            appendSearchToken(field: field, value: value)
            query = ""
            activeSearchField = nil
            isSearchCommitted = true
        }
        isSearchFocused = true
    }

    func openAdvancedFilterSheet() {
        advancedFilterDraft = HomeAdvancedFilterDraft(tokens: searchTokens)
        activeSearchField = nil
        isSearchFocused = false
        hideKeyboard()
        showsAdvancedFilterSheet = true
    }

    func applyAdvancedFilterDraft() {
        let baseTokens = HomeAdvancedFilterDraft.removingHistoryTokens(from: searchTokens)
        searchTokens = baseTokens + advancedFilterDraft.toHistoryTokens()
        isSearchCommitted = hasAnySearchCondition()
    }

    func clearAdvancedHistoryFilters() {
        searchTokens = HomeAdvancedFilterDraft.removingHistoryTokens(from: searchTokens)
        advancedFilterDraft.clearHistoryConditions()
        isSearchCommitted = hasAnySearchCondition()
    }

    func buildSearchSummaryText() -> String {
        let freeText = committedSearchState.trimmedFreeText
        let tokenCount = committedSearchState.tokens.count

        if freeText.isEmpty {
            return tokenCount > 0 ? "条件\(tokenCount)件" : ""
        }
        if tokenCount > 0 {
            return "“\(freeText)” + 条件\(tokenCount)件"
        }
        return "“\(freeText)”"
    }

    @ViewBuilder
    func episodeListRow(episode: Episode, width: CGFloat) -> some View {
        let isSelected = selectedEpisodeIDs.contains(episode.id)
        let trimmedBody = episode.body?.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = (trimmedBody?.isEmpty ?? true) ? "本文なし" : (trimmedBody ?? "本文なし")
        let rowView = EpisodeCardRow(
            title: episode.title,
            subtitle: subtitle,
            talkedCount: episode.talkedCount,
            latestTalkedAt: episode.latestTalkedAt,
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

    func sortedEpisodes(_ items: [Episode]) -> [Episode] {
        items.sorted { lhs, rhs in
            switch sortOption {
            case .createdAtDescending:
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
            case .createdAtAscending:
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
            case .recentlyTalked:
                let lhsLatest = lhs.latestTalkedAt ?? .distantPast
                let rhsLatest = rhs.latestTalkedAt ?? .distantPast
                if lhsLatest != rhsLatest {
                    return lhsLatest > rhsLatest
                }
                if lhs.talkedCount != rhs.talkedCount {
                    return lhs.talkedCount > rhs.talkedCount
                }
            case .longTimeNoTalk:
                let lhsNeverTalked = lhs.latestTalkedAt == nil
                let rhsNeverTalked = rhs.latestTalkedAt == nil
                if lhsNeverTalked != rhsNeverTalked {
                    return lhsNeverTalked
                }
                let lhsLatest = lhs.latestTalkedAt ?? .distantFuture
                let rhsLatest = rhs.latestTalkedAt ?? .distantFuture
                if lhsLatest != rhsLatest {
                    return lhsLatest < rhsLatest
                }
            case .talkedCountDescending:
                if lhs.talkedCount != rhs.talkedCount {
                    return lhs.talkedCount > rhs.talkedCount
                }
                let lhsLatest = lhs.latestTalkedAt ?? .distantPast
                let rhsLatest = rhs.latestTalkedAt ?? .distantPast
                if lhsLatest != rhsLatest {
                    return lhsLatest > rhsLatest
                }
            case .talkedCountAscending:
                if lhs.talkedCount != rhs.talkedCount {
                    return lhs.talkedCount < rhs.talkedCount
                }
                let lhsLatest = lhs.latestTalkedAt ?? .distantPast
                let rhsLatest = rhs.latestTalkedAt ?? .distantPast
                if lhsLatest != rhsLatest {
                    return lhsLatest < rhsLatest
                }
            }
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
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
            .font(AppTypography.subtextEmphasis)
            .foregroundColor(HomeStyle.selectionCancelText)

            Spacer(minLength: 0)

            Text("\(count)件選択")
                .font(AppTypography.subtextEmphasis)
                .foregroundColor(HomeStyle.selectionCountText)

            Spacer(minLength: 0)

            Button {
                onDelete()
            } label: {
                Text("削除")
                    .font(AppTypography.subtextEmphasis)
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

private enum HomeEpisodeSortOption: String, CaseIterable, Identifiable {
    case createdAtDescending = "登録日(新しい順)"
    case createdAtAscending = "登録日(古い順)"
    case recentlyTalked = "最近話した順"
    case longTimeNoTalk = "最近話していない順"
    case talkedCountDescending = "話した回数(降順)"
    case talkedCountAscending = "話した回数(昇順)"

    var id: String { rawValue }
}

private struct HomeEpisodeSortControl: View {
    @Binding var selection: HomeEpisodeSortOption
    let width: CGFloat

    private var widestLabel: String {
        HomeEpisodeSortOption.allCases
            .map(\.rawValue)
            .max(by: { $0.count < $1.count }) ?? selection.rawValue
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("並び替え")
                .font(HomeFont.bodyMedium())
                .foregroundColor(HomeStyle.subtitle)
            Spacer(minLength: 0)
            Menu {
                ForEach(HomeEpisodeSortOption.allCases) { option in
                    Button {
                        selection = option
                    } label: {
                        if selection == option {
                            Label(option.rawValue, systemImage: "checkmark")
                        } else {
                            Text(option.rawValue)
                        }
                    }
                }
            } label: {
                ZStack(alignment: .leading) {
                    // Keep width stable by reserving space for the longest sort label.
                    HStack(spacing: 6) {
                        Text(widestLabel)
                            .font(AppTypography.subtextEmphasis)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .opacity(0)
                    .accessibilityHidden(true)

                    HStack(spacing: 6) {
                        Text(selection.rawValue)
                            .font(AppTypography.subtextEmphasis)
                            .foregroundColor(HomeStyle.searchChipText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(HomeStyle.searchChipText.opacity(0.8))
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: HomeStyle.searchChipHeight)
                .background(HomeStyle.searchChipFill)
                .overlay(
                    Capsule()
                        .stroke(HomeStyle.searchChipBorder, lineWidth: 1)
                )
                .clipShape(Capsule())
            }
        }
        .frame(width: width, alignment: .leading)
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
