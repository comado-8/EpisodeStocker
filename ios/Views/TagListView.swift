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
    return tags.filter { $0.name.localizedCaseInsensitiveContains(normalized) }
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
        let bottomInset = baseSafeAreaBottom()
        let topPadding = max(0, TagStyle.figmaTopInset - proxy.safeAreaInsets.top)
        let fabBottomPadding = HomeStyle.tabBarHeight + TagStyle.fabBottomOffset
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSearching = !trimmedQuery.isEmpty

        ZStack(alignment: .bottomTrailing) {
          HomeStyle.background.ignoresSafeArea()

          ScrollView {
            VStack(spacing: TagStyle.sectionSpacing) {
              HomeSearchBarView(
                text: $query,
                width: contentWidth,
                isFocused: $isSearchFocused,
                placeholder: "タグを検索"
              )

              VStack(alignment: .leading, spacing: TagStyle.sectionSpacing) {
                Rectangle()
                  .fill(HomeStyle.outline)
                  .frame(width: contentWidth, height: HomeStyle.dividerHeight)

              TagHeaderView()

              if isSearching {
                TagSearchSummaryView(query: trimmedQuery, count: filteredTags.count)
              }

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
              }
              .frame(width: contentWidth, alignment: .leading)
              .simultaneousGesture(
                TapGesture().onEnded {
                  if isSearchFocused {
                    isSearchFocused = false
                    hideKeyboard()
                  }
                }
              )
            }
            .padding(.top, topPadding)
            .padding(.bottom, HomeStyle.tabBarHeight + 16 + bottomInset)
            .frame(maxWidth: .infinity)
          }

          HomeFloatingButton {
            editorContext = TagEditorContext(mode: .add)
          }
          .padding(.trailing, max(HomeStyle.fabTrailing, HomeStyle.horizontalPadding))
          .padding(.bottom, fabBottomPadding)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: TagRoute.self) { route in
          TagDetailView(tagID: route.tagID, tagName: route.tagName)
        }
      }
    }
    .overlay(alignment: .bottom) {
      if showsUndoToast {
        TagUndoToastView {
          undoDelete()
        }
        .padding(.bottom, HomeStyle.tabBarHeight + 12)
      }
    }
    .sheet(item: $editorContext) { context in
      TagEditorSheet(context: context, measuredHeight: $editorSheetHeight) { name in
        guard let normalized = normalizedTagName(name) else { return }
        switch context.mode {
        case .add:
          _ = modelContext.upsertTag(name: normalized)
          try? modelContext.save()
        }
      }
      .presentationDetents([.height(editorSheetHeight)])
      .presentationDragIndicator(.visible)
    }
  }
}

private struct TagHeaderView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("タグ管理")
        .font(TagStyle.headerFont)
        .foregroundColor(TagStyle.headerText)
      Text("登録されているタグの一覧です。スワイプで削除できます。")
        .font(TagStyle.subheaderFont)
        .foregroundColor(TagStyle.subheaderText)
        .fixedSize(horizontal: false, vertical: true)
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
        let listHeight = TagStyle.rowHeight * CGFloat(tags.count)
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
        .frame(height: listHeight)
        .modifier(TagListScrollDisable())
      }
    }
    .frame(width: width)
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

private struct TagListScrollDisable: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 16.0, *) {
      content.scrollDisabled(true)
    } else {
      content
    }
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
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button {
        onDelete()
      } label: {
        Text("削除")
          .font(TagStyle.swipeActionFont)
      }
      .tint(TagStyle.swipeActionTint)
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
  let onSave: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var name: String

  init(
    context: TagEditorContext, measuredHeight: Binding<CGFloat>, onSave: @escaping (String) -> Void
  ) {
    self.context = context
    self._measuredHeight = measuredHeight
    self.onSave = onSave
    _name = State(initialValue: context.initialName)
  }

  var body: some View {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let canSave = !trimmed.isEmpty

    VStack(alignment: .leading, spacing: 16) {
      Text(context.title)
        .font(TagStyle.editorTitleFont)
        .foregroundColor(TagStyle.headerText)

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
        }
        .padding(.horizontal, 12)
        .frame(height: TagStyle.editorInputHeight)
        .background(
          RoundedRectangle(cornerRadius: TagStyle.editorInputCornerRadius)
            .stroke(TagStyle.editorInputBorder, lineWidth: TagStyle.editorInputBorderWidth)
        )
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
          RoundedRectangle(cornerRadius: TagStyle.editorButtonCornerRadius)
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
          RoundedRectangle(cornerRadius: TagStyle.editorButtonCornerRadius)
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
      let maxHeight = UIScreen.main.bounds.height * 0.8
      measuredHeight = min(max(padded, 100), maxHeight)
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
    HStack(spacing: 12) {
      Text("削除しました")
        .font(TagStyle.toastFont)
        .foregroundColor(TagStyle.toastText)
      Spacer(minLength: 0)
      Button("元に戻す") {
        onUndo()
      }
      .font(TagStyle.toastButtonFont)
      .foregroundColor(TagStyle.toastButtonText)
    }
    .padding(.horizontal, 16)
    .frame(height: 44)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(TagStyle.toastFill)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(TagStyle.toastBorder, lineWidth: 1)
        )
    )
    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    .padding(.horizontal, 16)
  }
}

private func displayTagName(_ tag: Tag) -> String {
  if tag.name.hasPrefix("#") {
    return tag.name
  }
  return "#\(tag.name)"
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

  static let headerFont = Font.custom("Roboto-Bold", size: 20)
  static let cardHeaderFont = Font.custom("Roboto-Medium", size: 16)
  static let subheaderFont = Font.custom("Roboto", size: 13)
  static let rowTitleFont = Font.custom("Roboto-Bold", size: 15)
  static let rowMetaFont = Font.custom("Roboto", size: 12)
  static let toastFont = Font.custom("Roboto-Medium", size: 13)
  static let toastButtonFont = Font.custom("Roboto-Medium", size: 13)
  static let swipeActionFont = Font.custom("Roboto-Medium", size: 12)
  static let editorTitleFont = Font.custom("Roboto-Bold", size: 18)
  static let editorLabelFont = Font.custom("Roboto-Medium", size: 13)
  static let editorInputFont = Font.custom("Roboto", size: 16)
  static let editorButtonFont = Font.custom("Roboto-Bold", size: 15)
  static let editorPrimaryButtonFont = Font.system(size: 16, weight: .bold)
  static let editorPrefixFont = Font.custom("Roboto-Medium", size: 16)
  static let searchLabelFont = Font.custom("Roboto-Medium", size: 12)
  static let searchQueryFont = Font.custom("Roboto", size: 14)
  static let searchCountFont = Font.custom("Roboto", size: 13)
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
  static let swipeActionTint = HomeStyle.destructiveRed
  static let editorPlaceholderText = Color.black.opacity(0.5)
  static let editorInputText = Color(hex: "0A0A0A")
  static let editorInputBorder = Color(hex: "D1D5DC")
  static let editorPrefixText = Color(hex: "4A5565")
  static let searchLabelText = HomeStyle.fabRed
  static let searchLabelFill = HomeStyle.fabRed.opacity(0.08)
  static let searchQueryText = Color(hex: "4A5565")
  static let searchCountText = Color(hex: "4A5565")
  static let emptyTitleText = rowTitleText
  static let emptyBodyText = rowMetaText
  static let editorPrimaryFill = HomeStyle.fabRed
  static let editorPrimaryText = Color.white
  static let editorCancelBorder = Color(hex: "CAC4D0")
  static let editorCancelText = Color(hex: "49454F")

  static let toastFill = Color(hex: "FFFFFF")
  static let toastBorder = Color(hex: "E5E7EB")
  static let toastText = Color(hex: "2A2525")
  static let toastButtonText = HomeStyle.fabRed

  static let cardShadowPrimary = Color.black.opacity(0.12)
  static let cardShadowPrimaryRadius: CGFloat = 2
  static let cardShadowPrimaryY: CGFloat = 1
  static let cardShadowSecondary = Color.black.opacity(0.06)
  static let cardShadowSecondaryRadius: CGFloat = 6
  static let cardShadowSecondaryY: CGFloat = 3

  static let editorInputHeight: CGFloat = 44
  static let editorInputCornerRadius: CGFloat = 10
  static let editorInputBorderWidth: CGFloat = 0.66
  static let editorButtonHeight: CGFloat = 44
  static let editorButtonCornerRadius: CGFloat = 12
}

extension TagListView {
  fileprivate func baseSafeAreaBottom() -> CGFloat {
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

  fileprivate func deleteTag(_ tag: Tag) {
    let episodeIds = modelContext.softDeleteTag(tag)
    pendingUndo = PendingTagDelete(tag: tag, episodeIds: episodeIds)
    showsUndoToast = true
    undoTask?.cancel()
    undoTask = Task {
      try? await Task.sleep(nanoseconds: 3_000_000_000)
      if !Task.isCancelled {
        await MainActor.run {
          showsUndoToast = false
          pendingUndo = nil
        }
      }
    }
  }

  fileprivate func undoDelete() {
    guard let pendingUndo else { return }
    modelContext.restoreTag(pendingUndo.tag, episodeIds: pendingUndo.episodeIds)
    showsUndoToast = false
    self.pendingUndo = nil
    undoTask?.cancel()
  }

  fileprivate func normalizedTagName(_ value: String) -> String? {
    var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("#") {
      trimmed.removeFirst()
      trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard !trimmed.isEmpty else { return nil }
    return trimmed
  }

  fileprivate func normalizedQuery(_ value: String) -> String {
    var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("#") {
      trimmed.removeFirst()
      trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return trimmed
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
