import SwiftData
import SwiftUI

struct TagListView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(
    filter: #Predicate<Tag> { $0.isSoftDeleted == false },
    sort: [SortDescriptor(\Tag.nameNormalized)]
  )
  private var tags: [Tag]
  @Query(filter: #Predicate<Episode> { $0.isSoftDeleted == false })
  private var episodes: [Episode]
  @State private var query = ""
  @FocusState private var isSearchFocused: Bool
  @State private var showsUndoToast = false
  @State private var pendingUndo: PendingTagDelete?
  @State private var undoTask: Task<Void, Never>?
  @State private var editorContext: TagEditorContext?
  @State private var editorSheetHeight: CGFloat = 320
  @State private var navigationPath: [TagRoute] = []

  private var filteredTags: [Tag] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return tags }
    let normalized = normalizedQuery(trimmed)
    guard !normalized.isEmpty else { return tags }
    return tags.filter { tag in
      let normalizedTagName =
        EpisodePersistence.normalizeTagName(tag.name)?.name
        ?? EpisodePersistence.stripLeadingTagPrefix(
          EpisodePersistence.normalizeTagInputWhileEditing(tag.name)
        )
      return normalizedTagName.localizedCaseInsensitiveContains(normalized)
    }
  }

  private var episodeCountByTagId: [UUID: Int] {
    var result: [UUID: Int] = [:]
    for episode in episodes {
      for tag in episode.tags {
        result[tag.id, default: 0] += 1
      }
    }
    return result
  }

  var body: some View {
    NavigationStack(path: $navigationPath) {
      GeometryReader { proxy in
        let contentWidth = HomeStyle.contentWidth(for: proxy.size.width)
        let topPadding = max(0, TagStyle.figmaTopInset - proxy.safeAreaInsets.top)
        let fabBottomPadding =
          HomeStyle.tabBarHeight + TagStyle.fabBottomOffset
          + (showsUndoToast ? TagStyle.toastHeight + TagStyle.toastBottomPadding : 0)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSearching = !trimmedQuery.isEmpty

        ZStack(alignment: .bottomTrailing) {
          HomeStyle.background.ignoresSafeArea()

          VStack(spacing: TagStyle.sectionSpacing) {
            VStack(alignment: .leading, spacing: TagStyle.sectionSpacing) {
              TagHeaderView()

              HomeSearchBarView(
                text: $query,
                width: contentWidth,
                isFocused: $isSearchFocused,
                placeholder: "タグを検索"
              )

              Rectangle()
                .fill(HomeStyle.outline)
                .frame(width: contentWidth, height: HomeStyle.dividerHeight)

              TagCaptionView()

              if isSearching {
                TagSearchSummaryView(query: trimmedQuery, count: filteredTags.count)
              }
            }
            .frame(width: contentWidth, alignment: .leading)

            TagListCardView(
              tags: filteredTags,
              width: contentWidth,
              totalCount: tags.count,
              isSearching: isSearching,
              episodeCounts: episodeCountByTagId,
              onSelect: { tag in
                navigationPath.append(
                  TagRoute(tagID: tag.id, tagName: displayTagName(tag))
                )
              },
              onDelete: { tag in
                deleteTag(tag)
              }
            )
            .frame(maxHeight: .infinity, alignment: .top)
          }
          .simultaneousGesture(
            TapGesture().onEnded {
              if isSearchFocused {
                isSearchFocused = false
                hideKeyboard()
              }
            }
          )
          .padding(.top, topPadding)
          .padding(.bottom, HomeStyle.tabBarHeight + TagStyle.listBottomPadding)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

          HomeFloatingButton {
            editorContext = TagEditorContext(mode: .add)
          }
          .padding(.trailing, max(HomeStyle.fabTrailing, HomeStyle.horizontalPadding))
          .padding(.bottom, fabBottomPadding)

          if showsUndoToast {
            TagUndoToastView {
              undoDelete()
            }
            .frame(width: contentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, HomeStyle.tabBarHeight + TagStyle.toastBottomPadding)
            .transition(.move(edge: .bottom).combined(with: .opacity))
          }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: TagRoute.self) { route in
          TagDetailView(tagID: route.tagID, tagName: route.tagName)
        }
      }
    }
    .sheet(item: $editorContext) { context in
      NavigationStack {
        let existingTagNames = Set(tags.compactMap { EpisodePersistence.normalizeTagName($0.name)?.name })
        TagEditorSheet(
          context: context,
          measuredHeight: $editorSheetHeight,
          existingNormalizedTagNames: existingTagNames
        ) { name in
          guard let normalized = EpisodePersistence.validateTagNameInput(name).normalizedName else {
            return
          }
          guard !existingTagNames.contains(normalized) else { return }
          switch context.mode {
          case .add:
            _ = modelContext.upsertTag(name: normalized)
            try? modelContext.save()
          }
        }
        .navigationTitle(context.title)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button("閉じる") {
              editorContext = nil
            }
            .font(TagStyle.sheetCloseFont)
          }
        }
      }
      .presentationDetents([.height(editorSheetHeight)])
      .presentationDragIndicator(.visible)
      .presentationBackground(Color.white)
    }
  }
}

private struct TagHeaderView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("タグ管理")
        .font(TagStyle.headerFont)
        .foregroundColor(TagStyle.headerText)
    }
  }
}

private struct TagCaptionView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("左スワイプで削除できます。")
        .font(TagStyle.subheaderFont)
        .foregroundColor(TagStyle.subheaderText)
        .fixedSize(horizontal: false, vertical: true)

      HStack(alignment: .top, spacing: 6) {
        Image(systemName: "info.circle")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(TagStyle.noticeIconText)
          .padding(.top, 1)
        Text("タグを削除すると、紐づくエピソードからもタグが外れます。")
          .font(TagStyle.noticeFont)
          .foregroundColor(TagStyle.noticeText)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

private struct TagRoute: Hashable {
  let tagID: UUID
  let tagName: String
}

private struct TagListCardView: View {
  let tags: [Tag]
  let width: CGFloat
  let totalCount: Int
  let isSearching: Bool
  let episodeCounts: [UUID: Int]
  let onSelect: (Tag) -> Void
  let onDelete: (Tag) -> Void

  var body: some View {
    VStack(spacing: 0) {
      TagCardHeaderView(count: totalCount)
      if tags.isEmpty {
        TagEmptyStateView(isSearching: isSearching)
      } else {
        List {
          ForEach(Array(tags.enumerated()), id: \.element.id) { index, tag in
            let count = episodeCounts[tag.id, default: 0]
            TagRowView(
              displayName: displayTagName(tag),
              count: count,
              showsDivider: index < tags.count - 1,
              onTap: { onSelect(tag) },
              onDelete: { onDelete(tag) }
            )
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
          }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxHeight: .infinity)
      }
    }
    .frame(width: width)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: TagStyle.cardCornerRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: TagStyle.cardCornerRadius, style: .continuous)
        .stroke(TagStyle.cardBorder, lineWidth: TagStyle.cardBorderWidth)
    )
    .shadow(
      color: TagStyle.cardShadowPrimary, radius: TagStyle.cardShadowPrimaryRadius, x: 0,
      y: TagStyle.cardShadowPrimaryY
    )
    .shadow(
      color: TagStyle.cardShadowSecondary, radius: TagStyle.cardShadowSecondaryRadius, x: 0,
      y: TagStyle.cardShadowSecondaryY)
  }
}

private struct TagCardHeaderView: View {
  let count: Int

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "tag")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(TagStyle.headerIconTint)
      Text("全\(count)件のタグ")
        .font(TagStyle.cardHeaderFont)
        .foregroundColor(TagStyle.headerText)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, TagStyle.cardHorizontalPadding)
    .frame(height: TagStyle.cardHeaderHeight)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(TagStyle.rowDivider)
        .frame(height: TagStyle.rowDividerHeight)
    }
  }
}

private struct TagRowView: View {
  let displayName: String
  let count: Int
  let showsDivider: Bool
  let onTap: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: TagStyle.rowSpacing) {
      ZStack {
        Circle()
          .fill(TagStyle.tagIconFill)
          .frame(width: TagStyle.tagIconSize, height: TagStyle.tagIconSize)
        Image(systemName: "tag")
          .font(.system(size: TagStyle.tagIconGlyphSize, weight: .semibold))
          .foregroundColor(TagStyle.tagIconTint)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(displayName)
          .font(TagStyle.rowTitleFont)
          .foregroundColor(TagStyle.rowTitleText)

        Text("\(count)件のエピソード")
          .font(TagStyle.rowMetaFont)
          .foregroundColor(TagStyle.rowMetaText)
      }

      Spacer(minLength: 0)

      Image(systemName: "chevron.right")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(TagStyle.rowMetaText)
        .accessibilityHidden(true)
    }
    .padding(.horizontal, TagStyle.rowHorizontalPadding)
    .frame(height: TagStyle.rowHeight)
    .contentShape(Rectangle())
    .onTapGesture {
      onTap()
    }
    .overlay(alignment: .bottom) {
      if showsDivider {
        Rectangle()
          .fill(TagStyle.rowDivider)
          .frame(height: TagStyle.rowDividerHeight)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      Button(role: .destructive) {
        onDelete()
      } label: {
        Label("削除", systemImage: "trash.fill")
          .font(TagStyle.swipeActionFont)
      }
    }
  }
}

private struct TagEmptyStateView: View {
  let isSearching: Bool

  var body: some View {
    VStack(spacing: 8) {
      if isSearching {
        Text("検索結果が見つかりません")
          .font(TagStyle.emptyTitleFont)
          .foregroundColor(TagStyle.emptyTitleText)
        Text("別のキーワードで検索してください")
          .font(TagStyle.emptyBodyFont)
          .foregroundColor(TagStyle.emptyBodyText)
      } else {
        Text("タグがまだありません")
          .font(TagStyle.emptyTitleFont)
          .foregroundColor(TagStyle.emptyTitleText)
        Text("右下の＋から追加できます")
          .font(TagStyle.emptyBodyFont)
          .foregroundColor(TagStyle.emptyBodyText)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
  }
}

private struct TagSearchSummaryView: View {
  let query: String
  let count: Int

  var body: some View {
    HStack(spacing: 8) {
      Text("検索結果")
        .font(TagStyle.searchLabelFont)
        .foregroundColor(TagStyle.searchLabelText)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(TagStyle.searchLabelFill)
        .clipShape(Capsule())

      Text("“\(query)”")
        .font(TagStyle.searchQueryFont)
        .foregroundColor(TagStyle.searchQueryText)
        .lineLimit(1)

      Spacer(minLength: 0)

      Text("\(count)件")
        .font(TagStyle.searchCountFont)
        .foregroundColor(TagStyle.searchCountText)
    }
  }
}

private struct TagEditorContext: Identifiable {
  enum Mode {
    case add
  }

  let id = UUID()
  let mode: Mode

  var title: String {
    switch mode {
    case .add: return "タグを追加"
    }
  }

  var actionTitle: String {
    switch mode {
    case .add: return "追加"
    }
  }

  var initialName: String {
    switch mode {
    case .add:
      return ""
    }
  }
}

private struct TagEditorSheet: View {
  let context: TagEditorContext
  @Binding var measuredHeight: CGFloat
  let existingNormalizedTagNames: Set<String>
  let onSave: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var name: String

  init(
    context: TagEditorContext,
    measuredHeight: Binding<CGFloat>,
    existingNormalizedTagNames: Set<String>,
    onSave: @escaping (String) -> Void
  ) {
    self.context = context
    self._measuredHeight = measuredHeight
    self.existingNormalizedTagNames = existingNormalizedTagNames
    self.onSave = onSave
    _name = State(initialValue: context.initialName)
  }

  var body: some View {
    GeometryReader { proxy in
      let validationResult = EpisodePersistence.validateTagNameInput(name)
      let normalizedName = validationResult.normalizedName
      let duplicateName = normalizedName.flatMap { candidate in
        existingNormalizedTagNames.contains(candidate) ? candidate : nil
      }
      let canSave = normalizedName != nil && duplicateName == nil
      let errorMessage =
        duplicateName.map { "既に「#\($0)」が登録されています" }
        ?? TagInputHelpers.validationMessage(for: validationResult)

      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text("タグ名")
            .font(TagStyle.editorLabelFont)
            .foregroundColor(TagStyle.subheaderText)

          HStack(spacing: 8) {
            Text("#")
              .font(TagStyle.editorPrefixFont)
              .foregroundColor(TagStyle.editorPrefixText)
              .frame(width: 16, alignment: .center)

            TextField(
              "", text: $name, prompt: Text("タグを入力").foregroundColor(TagStyle.editorPlaceholderText)
            )
            .font(TagStyle.editorInputFont)
            .foregroundColor(TagStyle.editorInputText)
            .onChange(of: name) { _, newValue in
              let normalized = EpisodePersistence.normalizeTagInputWhileEditing(newValue)
              if normalized != newValue {
                name = normalized
              }
            }
          }
          .padding(.horizontal, 12)
          .frame(height: TagStyle.editorInputHeight)
          .background(
            RoundedRectangle(cornerRadius: TagStyle.editorInputCornerRadius)
              .stroke(TagStyle.editorInputBorder, lineWidth: TagStyle.editorInputBorderWidth)
          )

          if let errorMessage {
            Text(errorMessage)
              .font(TagStyle.editorValidationFont)
              .foregroundColor(TagStyle.validationText)
              .fixedSize(horizontal: false, vertical: true)
          }

          Text(TagInputConstants.guideText)
            .font(TagStyle.editorGuideFont)
            .foregroundColor(TagStyle.guideText)
            .fixedSize(horizontal: false, vertical: true)
        }

        HStack(spacing: 12) {
          Button("キャンセル") {
            dismiss()
          }
          .font(TagStyle.editorButtonFont)
          .foregroundColor(TagStyle.editorCancelText)
          .frame(maxWidth: .infinity)
          .frame(height: TagStyle.editorButtonHeight)
          .background(
            Capsule()
              .stroke(TagStyle.editorCancelBorder, lineWidth: 1)
          )

          Button(context.actionTitle) {
            onSave(name)
            dismiss()
          }
          .font(TagStyle.editorPrimaryButtonFont)
          .foregroundColor(TagStyle.editorPrimaryText)
          .frame(maxWidth: .infinity)
          .frame(height: TagStyle.editorButtonHeight)
          .background(
            Capsule()
              .fill(TagStyle.editorPrimaryFill)
          )
          .disabled(!canSave)
          .opacity(canSave ? 1 : 0.5)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .background(Color.white)
      .background(
        GeometryReader { proxy in
          Color.clear.preference(key: TagEditorHeightKey.self, value: proxy.size.height)
        }
      )
      .onPreferenceChange(TagEditorHeightKey.self) { height in
        let padded = height
        let maxHeight = proxy.size.height * 0.8
        measuredHeight = min(max(padded, 100), maxHeight)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }
}

private struct TagEditorHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 320

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

private struct PendingTagDelete {
  let tag: Tag
  let episodeIds: [UUID]
}

private struct TagUndoToastView: View {
  let onUndo: () -> Void

  var body: some View {
    HStack(spacing: 14) {
      Text("タグを削除しました")
        .font(TagStyle.toastFont)
        .foregroundColor(TagStyle.toastText)
      Spacer(minLength: 0)
      Button {
        onUndo()
      }
      label: {
        HStack(spacing: 6) {
          Image(systemName: "arrow.uturn.backward")
            .font(.system(size: 13, weight: .semibold))
          Text("元に戻す")
            .font(TagStyle.toastButtonFont)
        }
        .foregroundColor(TagStyle.toastButtonText)
        .padding(.horizontal, 14)
        .frame(height: TagStyle.toastButtonHeight)
        .background(
          Capsule()
            .fill(TagStyle.toastButtonFill)
        )
      }
    }
    .padding(.horizontal, TagStyle.toastHorizontalPadding)
    .frame(height: TagStyle.toastHeight)
    .background(
      RoundedRectangle(cornerRadius: TagStyle.toastCornerRadius)
        .fill(TagStyle.toastFill)
        .overlay(
          RoundedRectangle(cornerRadius: TagStyle.toastCornerRadius)
            .stroke(TagStyle.toastBorder, lineWidth: TagStyle.toastBorderWidth)
        )
    )
    .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 8)
  }
}

private func displayTagName(_ tag: Tag) -> String {
  let normalized = EpisodePersistence.normalizeTagName(tag.name)?.name
    ?? EpisodePersistence.stripLeadingTagPrefix(tag.name).lowercased()
  guard !normalized.isEmpty else { return "#" }
  return "#\(normalized)"
}

private enum TagStyle {
  static let figmaTopInset: CGFloat = 59
  static let sectionSpacing: CGFloat = 16
  static let rowSpacing: CGFloat = 14
  static let rowHeight: CGFloat = 76
  static let rowHorizontalPadding: CGFloat = 20

  static let cardCornerRadius: CGFloat = 10
  static let cardHeaderHeight: CGFloat = 56
  static let cardBorderWidth: CGFloat = 0.66
  static let cardHorizontalPadding: CGFloat = 16
  static let rowDividerHeight: CGFloat = 0.66

  static let actionButtonSize: CGFloat = 32
  static let actionIconSize: CGFloat = 15
  static let actionSpacing: CGFloat = 6
  static let actionButtonCornerRadius: CGFloat = 10

  static let tagIconSize: CGFloat = 40
  static let tagIconGlyphSize: CGFloat = 18

  static let fabBottomOffset: CGFloat = 8
  static let listBottomPadding: CGFloat = 0

  static let headerFont = AppTypography.screenTitle
  static let cardHeaderFont = Font.system(size: 16, weight: .medium)
  static let subheaderFont = Font.system(size: 13, weight: .regular)
  static let rowTitleFont = Font.system(size: 18, weight: .semibold)
  static let rowMetaFont = Font.system(size: 12, weight: .regular)
  static let toastFont = Font.system(size: 15, weight: .bold)
  static let toastButtonFont = Font.system(size: 15, weight: .heavy)
  static let swipeActionFont = Font.system(size: 12, weight: .medium)
  static let noticeFont = Font.system(size: 12, weight: .regular)
  static let editorLabelFont = Font.system(size: 13, weight: .medium)
  static let editorInputFont = Font.system(size: 16, weight: .regular)
  static let editorButtonFont = Font.system(size: 15, weight: .bold)
  static let editorPrimaryButtonFont = Font.system(size: 16, weight: .bold)
  static let sheetCloseFont = Font.system(size: 15, weight: .semibold)
  static let editorPrefixFont = Font.system(size: 16, weight: .medium)
  static let editorValidationFont = Font.system(size: 12, weight: .regular)
  static let editorGuideFont = Font.system(size: 12, weight: .regular)
  static let searchLabelFont = Font.system(size: 12, weight: .medium)
  static let searchQueryFont = Font.system(size: 14, weight: .regular)
  static let searchCountFont = Font.system(size: 13, weight: .regular)
  static let emptyTitleFont = rowTitleFont
  static let emptyBodyFont = rowMetaFont

  static let headerText = Color(hex: "2A2525")
  static let subheaderText = Color(hex: "6B7280")
  static let rowTitleText = Color(hex: "2A2525")
  static let rowMetaText = Color(hex: "6B7280")
  static let rowDivider = Color(hex: "E5E7EB")
  static let cardBorder = Color(hex: "E5E7EB")
  static let headerIconTint = Color(hex: "101828")
  static let tagIconFill = Color(hex: "F3F4F6")
  static let tagIconTint = Color(hex: "364153")
  static let editIconTint = HomeStyle.fabRed
  static let editButtonFill = HomeStyle.fabRed.opacity(0.12)
  static let editButtonBorder = HomeStyle.fabRed.opacity(0.45)
  static let editorPlaceholderText = Color.black.opacity(0.5)
  static let editorInputText = Color(hex: "0A0A0A")
  static let editorInputBorder = Color(hex: "D1D5DC")
  static let editorPrefixText = Color(hex: "4A5565")
  static let searchLabelText = HomeStyle.fabRed
  static let searchLabelFill = HomeStyle.fabRed.opacity(0.08)
  static let searchQueryText = Color(hex: "4A5565")
  static let searchCountText = Color(hex: "4A5565")
  static let noticeText = Color(hex: "4A5565")
  static let noticeIconText = Color(hex: "4A5565")
  static let emptyTitleText = rowTitleText
  static let emptyBodyText = rowMetaText
  static let editorPrimaryFill = HomeStyle.fabRed
  static let editorPrimaryText = Color.white
  static let editorCancelBorder = Color(hex: "CAC4D0")
  static let editorCancelText = Color(hex: "49454F")
  static let validationText = HomeStyle.destructiveRed
  static let guideText = Color(hex: "6B7280")

  static let toastFill = Color(hex: "FFF4F4")
  static let toastBorder = HomeStyle.fabRed.opacity(0.32)
  static let toastText = Color(hex: "2A2525")
  static let toastButtonText = Color.white
  static let toastButtonFill = HomeStyle.fabRed

  static let cardShadowPrimary = Color.black.opacity(0.12)
  static let cardShadowPrimaryRadius: CGFloat = 2
  static let cardShadowPrimaryY: CGFloat = 1
  static let cardShadowSecondary = Color.black.opacity(0.06)
  static let cardShadowSecondaryRadius: CGFloat = 6
  static let cardShadowSecondaryY: CGFloat = 3

  static let editorInputHeight: CGFloat = 44
  static let editorInputCornerRadius: CGFloat = 10
  static let editorInputBorderWidth: CGFloat = 0.66
  static let editorButtonHeight: CGFloat = 48
  static let toastHeight: CGFloat = 60
  static let toastCornerRadius: CGFloat = 14
  static let toastHorizontalPadding: CGFloat = 18
  static let toastButtonHeight: CGFloat = 36
  static let toastBorderWidth: CGFloat = 1.2
  static let toastBottomPadding: CGFloat = 10
}

extension TagListView {
  fileprivate func deleteTag(_ tag: Tag) {
    let episodeIds = modelContext.softDeleteTag(tag)
    pendingUndo = PendingTagDelete(tag: tag, episodeIds: episodeIds)
    withAnimation(.easeInOut(duration: 0.2)) {
      showsUndoToast = true
    }
    undoTask?.cancel()
    undoTask = Task {
      try? await Task.sleep(nanoseconds: 3_000_000_000)
      if !Task.isCancelled {
        await MainActor.run {
          withAnimation(.easeInOut(duration: 0.2)) {
            showsUndoToast = false
          }
          pendingUndo = nil
        }
      }
    }
  }

  fileprivate func undoDelete() {
    guard let pendingUndo else { return }
    modelContext.restoreTag(pendingUndo.tag, episodeIds: pendingUndo.episodeIds)
    withAnimation(.easeInOut(duration: 0.2)) {
      showsUndoToast = false
    }
    self.pendingUndo = nil
    undoTask?.cancel()
  }

  fileprivate func normalizedQuery(_ value: String) -> String {
    EpisodePersistence.stripLeadingTagPrefix(
      EpisodePersistence.normalizeTagInputWhileEditing(
        value.trimmingCharacters(in: .whitespacesAndNewlines)
      )
    )
  }
}

extension View {
  fileprivate func hideKeyboard() {
    #if canImport(UIKit)
      UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #endif
  }
}

struct TagListView_Previews: PreviewProvider {
  static var previews: some View {
    TagListView().environmentObject(EpisodeStore())
  }
}
