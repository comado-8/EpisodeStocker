import SwiftUI

struct InlineSuggestionList: View {
  @EnvironmentObject private var store: EpisodeStore
  let fieldType: String
  @Binding var query: String
  let maxItems: Int
  let isActive: Bool
  let showWhenQueryEmpty: Bool
  let onSelect: (String) -> Void

  @State private var suggestions: [Suggestion] = []

  init(
    fieldType: String,
    query: Binding<String>,
    maxItems: Int,
    isActive: Bool,
    showWhenQueryEmpty: Bool = true,
    onSelect: @escaping (String) -> Void
  ) {
    self.fieldType = fieldType
    self._query = query
    self.maxItems = maxItems
    self.isActive = isActive
    self.showWhenQueryEmpty = showWhenQueryEmpty
    self.onSelect = onSelect
  }

  private func reload() {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    var result: [Suggestion] = []
    if trimmedQuery.isEmpty {
      if showWhenQueryEmpty {
        result = store.suggestionRepository.fetch(
          fieldType: fieldType, query: nil, includeDeleted: false)
      } else {
        result = []
      }
    } else {
      result = store.suggestionRepository.fetch(
        fieldType: fieldType, query: trimmedQuery, includeDeleted: false)
    }
    if result.count > maxItems { result = Array(result.prefix(maxItems)) }
    suggestions = result
  }

  var body: some View {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let showsForEmptyQuery = trimmedQuery.isEmpty && showWhenQueryEmpty
    let showsForTypedQuery = !trimmedQuery.isEmpty && isActive
    let shouldShow = showsForEmptyQuery || showsForTypedQuery

    VStack(alignment: .leading, spacing: 8) {
      if shouldShow {
        HStack(spacing: 8) {
          Button(action: {
            NotificationCenter.default.post(
              name: .openSuggestionManagerSheet, object: fieldType)
          }) {
            HStack(spacing: 4) {
              Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12, weight: .semibold))
              Text("履歴管理/選択")
            }
            .font(InlineSuggestionStyle.manageFont)
            .foregroundColor(InlineSuggestionStyle.manageText)
            .padding(.horizontal, 10)
            .frame(height: InlineSuggestionStyle.manageHeight)
            .background(InlineSuggestionStyle.manageFill)
            .overlay(
              Capsule()
                .stroke(InlineSuggestionStyle.manageBorder, lineWidth: 1)
            )
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: InlineSuggestionStyle.chipSpacing) {
              ForEach(suggestions, id: \.id) { s in
                Button(action: {
                  onSelect(s.value)
                  store.suggestionRepository.upsert(fieldType: fieldType, value: s.value)
                }) {
                  Text(s.value)
                    .font(InlineSuggestionStyle.chipFont)
                    .foregroundColor(InlineSuggestionStyle.chipText)
                    .padding(.horizontal, 12)
                    .frame(height: InlineSuggestionStyle.chipHeight)
                    .background(InlineSuggestionStyle.chipFill)
                    .overlay(
                      Capsule()
                        .stroke(InlineSuggestionStyle.chipBorder, lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .onAppear { reload() }
    .onChange(of: query) { _, _ in reload() }
    .onChange(of: isActive) { _, _ in reload() }
    .onReceive(NotificationCenter.default.publisher(for: .suggestionManagerSheetDidDismiss)) {
      note in
      guard let dismissedFieldType = note.object as? String, dismissedFieldType == fieldType else {
        return
      }
      reload()
    }
  }
}

private enum InlineSuggestionStyle {
  static let chipSpacing: CGFloat = 8
  static let chipHeight: CGFloat = 28
  static let manageHeight: CGFloat = 26

  static let chipText = Color(hex: "364153")
  static let chipFill = Color(hex: "F3F4F6")
  static let chipBorder = Color(hex: "D1D5DC")
  static let manageText = HomeStyle.fabRed
  static let manageFill = HomeStyle.fabRed.opacity(0.08)
  static let manageBorder = HomeStyle.fabRed.opacity(0.4)

  static let chipFont = Font.system(size: 14, weight: .medium)
  static let manageFont = Font.system(size: 12, weight: .medium)
}

extension Notification.Name {
  static let openSuggestionManagerSheet = Notification.Name("openSuggestionManagerSheet")
  static let suggestionManagerSheetDidDismiss = Notification.Name(
    "suggestionManagerSheetDidDismiss")
}
