import SwiftData
import SwiftUI

struct SuggestionManagerView: View {
  @Environment(\.dismiss) private var dismiss
  @Query(filter: #Predicate<Episode> { $0.isSoftDeleted == false })
  private var episodes: [Episode]
  @Query(filter: #Predicate<Person> { $0.isSoftDeleted == false })
  private var persons: [Person]
  @Query(filter: #Predicate<Project> { $0.isSoftDeleted == false })
  private var projects: [Project]
  @Query(filter: #Predicate<Emotion> { $0.isSoftDeleted == false })
  private var emotions: [Emotion]
  @Query(filter: #Predicate<Place> { $0.isSoftDeleted == false })
  private var places: [Place]
  @Query(filter: #Predicate<Tag> { $0.isSoftDeleted == false })
  private var tags: [Tag]
  @StateObject private var vm: SuggestionManagerViewModel
  @State private var showsUndoToast = false
  private let onSelect: ((String) -> Void)?
  private let repository: SuggestionRepository
  private let fieldType: String

  init(
    repository: SuggestionRepository,
    fieldType: String,
    onSelect: ((String) -> Void)? = nil
  ) {
    self.repository = repository
    self.fieldType = fieldType
    _vm = StateObject(
      wrappedValue: SuggestionManagerViewModel(repository: repository, fieldType: fieldType))
    self.onSelect = onSelect
  }

  var body: some View {
    NavigationStack {
      ZStack {
        Color.white.ignoresSafeArea()

        VStack(spacing: SuggestionManagerStyle.sectionSpacing) {
          controlsCard

          List {
            ForEach(vm.suggestions) { suggestion in
              let activeCount = activeUsageCount(for: suggestion.value)
              let isDeletionProtected = isDeletionProtectedSuggestion(
                suggestion: suggestion,
                activeUsageCount: activeCount
              )
              SuggestionRow(
                suggestion: suggestion,
                isDeletionProtected: isDeletionProtected,
                protectedUsageCount: activeCount
              )
                .contentShape(Rectangle())
                .onTapGesture {
                  guard let onSelect, !suggestion.isDeleted else { return }
                  onSelect(suggestion.value)
                  dismiss()
                }
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: !isDeletionProtected) {
                  if suggestion.isDeleted {
                    Button {
                      vm.restore(suggestion.id)
                    } label: {
                      swipeActionLabel(
                        title: "復元",
                        fill: SuggestionManagerStyle.restoreFill,
                        text: SuggestionManagerStyle.restoreText
                      )
                    }
                    .tint(SuggestionManagerStyle.restoreFill)
                  } else if isDeletionProtected {
                    Button {} label: {
                      swipeActionLabel(
                        title: "使用中",
                        fill: SuggestionManagerStyle.protectedFill,
                        text: SuggestionManagerStyle.protectedText
                      )
                    }
                    .tint(SuggestionManagerStyle.protectedFill)
                    .disabled(true)
                  } else {
                    Button {
                      vm.softDelete(suggestion.id)
                      showsUndoToast = true
                      Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        showsUndoToast = false
                      }
                    } label: {
                      swipeActionLabel(
                        title: "削除",
                        fill: SuggestionManagerStyle.destructiveFill,
                        text: SuggestionManagerStyle.destructiveText
                      )
                    }
                    .tint(SuggestionManagerStyle.destructiveFill)
                  }
                }
            }
          }
          .listStyle(.plain)
          .scrollContentBackground(.hidden)
          .modifier(SuggestionManagerRowSpacing())
        }
        .padding(.horizontal, SuggestionManagerStyle.horizontalPadding)
        .padding(.top, 12)
      }
      .navigationTitle("履歴を管理")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("閉じる") {
            dismiss()
          }
          .font(SuggestionManagerStyle.headerCloseFont)
        }
      }
      .overlay(alignment: .bottom) {
        if showsUndoToast {
          HStack(spacing: 14) {
            Text("履歴を削除しました")
              .font(SuggestionManagerStyle.toastFont)
              .foregroundColor(SuggestionManagerStyle.toastText)
            Spacer(minLength: 0)
            Button {
              vm.undoDelete()
              showsUndoToast = false
            } label: {
              HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                  .font(.system(size: 13, weight: .semibold))
                Text("元に戻す")
                  .font(SuggestionManagerStyle.toastButtonFont)
              }
              .foregroundColor(SuggestionManagerStyle.toastButtonText)
              .padding(.horizontal, 14)
              .frame(height: SuggestionManagerStyle.toastButtonHeight)
              .background(
                Capsule()
                  .fill(SuggestionManagerStyle.toastButtonFill)
              )
            }
          }
          .padding(.horizontal, SuggestionManagerStyle.toastHorizontalPadding)
          .frame(height: SuggestionManagerStyle.toastHeight)
          .background(
            RoundedRectangle(cornerRadius: SuggestionManagerStyle.toastCornerRadius)
              .fill(SuggestionManagerStyle.toastFill)
              .overlay(
                RoundedRectangle(cornerRadius: SuggestionManagerStyle.toastCornerRadius)
                  .stroke(SuggestionManagerStyle.toastBorder, lineWidth: SuggestionManagerStyle.toastBorderWidth)
              )
          )
          .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 8)
          .padding(.bottom, SuggestionManagerStyle.toastBottomPadding)
          .animation(.easeInOut, value: showsUndoToast)
        }
      }
    }
    .onAppear {
      primeRepositoryFromEpisodeData()
      vm.fetch()
    }
  }

  private var controlsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("対象: \(vm.title)")
        .font(SuggestionManagerStyle.subheaderFont)
        .foregroundColor(SuggestionManagerStyle.subheaderText)

      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(SuggestionManagerStyle.inputIcon)
        TextField("検索", text: $vm.query)
          .font(SuggestionManagerStyle.inputFont)
          .foregroundColor(SuggestionManagerStyle.inputText)
      }
      .padding(.horizontal, 12)
      .frame(height: SuggestionManagerStyle.inputHeight)
      .background(
        RoundedRectangle(cornerRadius: SuggestionManagerStyle.inputCornerRadius)
          .fill(SuggestionManagerStyle.inputFill)
          .overlay(
            RoundedRectangle(cornerRadius: SuggestionManagerStyle.inputCornerRadius)
              .stroke(
                SuggestionManagerStyle.inputBorder,
                lineWidth: SuggestionManagerStyle.inputBorderWidth)
          )
      )

      Toggle(isOn: $vm.includeDeleted) {
        VStack(alignment: .leading, spacing: 4) {
          Text("削除済みを表示")
            .font(SuggestionManagerStyle.toggleTitleFont)
            .foregroundColor(SuggestionManagerStyle.toggleTitleText)
          Text("ONにすると削除済み候補を表示し、復元できます")
            .font(SuggestionManagerStyle.toggleBodyFont)
            .foregroundColor(SuggestionManagerStyle.toggleBodyText)
        }
      }
      .toggleStyle(SwitchToggleStyle(tint: SuggestionManagerStyle.toggleTint))
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: SuggestionManagerStyle.cardCornerRadius)
        .fill(SuggestionManagerStyle.cardFill)
        .overlay(
          RoundedRectangle(cornerRadius: SuggestionManagerStyle.cardCornerRadius)
            .stroke(SuggestionManagerStyle.cardBorder, lineWidth: 1)
        )
    )
  }

  private func primeRepositoryFromEpisodeData() {
    let existing = existingValuesForField().map {
      $0.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    .filter { !$0.isEmpty }
    guard !existing.isEmpty else { return }

    var current = repository.fetch(fieldType: fieldType, query: nil, includeDeleted: true).map(\.value)
    for value in existing {
      let exists = current.contains { $0.caseInsensitiveCompare(value) == .orderedSame }
      if !exists {
        repository.upsert(fieldType: fieldType, value: value)
        current.append(value)
      }
    }
  }

  private func existingValuesForField() -> [String] {
    switch fieldType {
    case "人物":
      return persons.map(\.name)
    case "企画名":
      return projects.map(\.name)
    case "感情":
      return emotions.map(\.name)
    case "場所":
      return places.map(\.name)
    case "タグ":
      return tags.map { tag in
        guard let normalized = EpisodePersistence.normalizeTagName(tag.name)?.name else {
          return ""
        }
        return "#\(normalized)"
      }
    default:
      return []
    }
  }

  private func swipeActionLabel(title: String, fill: Color, text: Color) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: SuggestionManagerStyle.rowCornerRadius, style: .continuous)
        .fill(fill)
      Text(title)
        .font(SuggestionManagerStyle.swipeActionFont)
        .foregroundColor(text)
    }
    .frame(width: 72, height: SuggestionManagerStyle.rowHeight)
  }

  private func isDeletionProtectedSuggestion(
    suggestion: Suggestion,
    activeUsageCount: Int
  ) -> Bool {
    guard !suggestion.isDeleted else { return false }
    guard fieldType != "感情" else { return false }
    return activeUsageCount > 0
  }

  private func activeUsageCount(for value: String) -> Int {
    guard let normalizedValue = normalizedValueForField(value, fieldType: fieldType) else {
      return 0
    }
    return episodes.reduce(into: 0) { count, episode in
      let hasValue: Bool
      switch fieldType {
      case "人物":
        hasValue = episode.persons.contains {
          normalizedValueForField($0.name, fieldType: "人物") == normalizedValue
        }
      case "企画名":
        hasValue = episode.projects.contains {
          normalizedValueForField($0.name, fieldType: "企画名") == normalizedValue
        }
      case "場所":
        hasValue = episode.places.contains {
          normalizedValueForField($0.name, fieldType: "場所") == normalizedValue
        }
      case "タグ":
        hasValue = episode.tags.contains {
          normalizedValueForField("#\($0.name)", fieldType: "タグ") == normalizedValue
        }
      default:
        hasValue = false
      }
      if hasValue {
        count += 1
      }
    }
  }

  private func normalizedValueForField(_ value: String, fieldType: String) -> String? {
    switch fieldType {
    case "タグ":
      return EpisodePersistence.normalizeTagName(value)?.normalized
    default:
      return EpisodePersistence.normalizeName(value)?.normalized
    }
  }
}

private struct SuggestionManagerRowSpacing: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 16.0, *) {
      content.listRowSpacing(SuggestionManagerStyle.rowSpacing)
    } else {
      content
    }
  }
}

private struct SuggestionRow: View {
  let suggestion: Suggestion
  let isDeletionProtected: Bool
  let protectedUsageCount: Int

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 0) {
        Text(suggestion.value)
          .font(SuggestionManagerStyle.rowTitleFont)
          .foregroundColor(
            suggestion.isDeleted
              ? SuggestionManagerStyle.deletedText : SuggestionManagerStyle.rowTitleText)
      }
      Spacer(minLength: 0)
      if suggestion.isDeleted {
        Text("削除済み")
          .font(SuggestionManagerStyle.deletedBadgeFont)
          .foregroundColor(SuggestionManagerStyle.deletedBadgeText)
          .padding(.horizontal, 8)
          .frame(height: 20)
          .background(
            Capsule()
              .fill(SuggestionManagerStyle.deletedBadgeFill)
              .overlay(
                Capsule()
                  .stroke(SuggestionManagerStyle.deletedBadgeBorder, lineWidth: 1)
              )
          )
      } else if isDeletionProtected {
        Text("使用中\(protectedUsageCount)件")
          .font(SuggestionManagerStyle.inUseBadgeFont)
          .foregroundColor(SuggestionManagerStyle.inUseBadgeText)
          .padding(.horizontal, 8)
          .frame(height: 20)
          .background(
            Capsule()
              .fill(SuggestionManagerStyle.inUseBadgeFill)
              .overlay(
                Capsule()
                  .stroke(SuggestionManagerStyle.inUseBadgeBorder, lineWidth: 1)
              )
          )
      }
    }
    .padding(.horizontal, SuggestionManagerStyle.rowHorizontalPadding)
    .padding(.vertical, SuggestionManagerStyle.rowVerticalPadding)
    .frame(height: SuggestionManagerStyle.rowHeight)
    .background(
      RoundedRectangle(cornerRadius: SuggestionManagerStyle.rowCornerRadius, style: .continuous)
        .fill(SuggestionManagerStyle.rowFill)
        .overlay(
          RoundedRectangle(cornerRadius: SuggestionManagerStyle.rowCornerRadius, style: .continuous)
            .stroke(SuggestionManagerStyle.rowBorder, lineWidth: 1)
        )
    )
  }
}

private enum SuggestionManagerStyle {
  static let horizontalPadding: CGFloat = 16
  static let sectionSpacing: CGFloat = 16
  static let inputHeight: CGFloat = 40
  static let inputCornerRadius: CGFloat = 10
  static let inputBorderWidth: CGFloat = 0.66
  static let cardCornerRadius: CGFloat = 12
  static let rowCornerRadius: CGFloat = 12
  static let rowHeight: CGFloat = 56
  static let rowVerticalPadding: CGFloat = 8
  static let rowHorizontalPadding: CGFloat = 12
  static let rowSpacing: CGFloat = 10

  static let cardFill = Color(hex: "F9FAFB")
  static let cardBorder = Color(hex: "E5E7EB")
  static let inputFill = Color(hex: "FFFFFF")
  static let inputBorder = Color(hex: "D1D5DC")
  static let inputText = Color(hex: "0A0A0A")
  static let inputIcon = Color(hex: "6B7280")
  static let subheaderText = Color(hex: "6B7280")
  static let toggleTitleText = Color(hex: "2A2525")
  static let toggleBodyText = Color(hex: "6B7280")
  static let toggleTint = HomeStyle.fabRed

  static let rowFill = Color(hex: "FFFFFF")
  static let rowBorder = Color(hex: "E5E7EB")
  static let rowTitleText = Color(hex: "2A2525")
  static let deletedText = Color(hex: "9CA3AF")
  static let deletedBadgeFill = Color(hex: "F3F4F6")
  static let deletedBadgeBorder = Color(hex: "D1D5DC")
  static let deletedBadgeText = Color(hex: "6B7280")
  static let destructiveFill = HomeStyle.destructiveRed
  static let destructiveText = Color.white
  static let restoreFill = Color(hex: "16A34A")
  static let restoreText = Color.white
  static let protectedFill = Color(hex: "9CA3AF")
  static let protectedText = Color.white
  static let inUseBadgeFill = Color(hex: "FEF3C7")
  static let inUseBadgeBorder = Color(hex: "F59E0B")
  static let inUseBadgeText = Color(hex: "92400E")

  static let toastFill = Color(hex: "FFF4F4")
  static let toastBorder = HomeStyle.fabRed.opacity(0.32)
  static let toastText = Color(hex: "2A2525")
  static let toastButtonText = Color.white
  static let toastButtonFill = HomeStyle.fabRed

  static let headerCloseFont = Font.system(size: 15, weight: .semibold)
  static let subheaderFont = Font.custom("Roboto", size: 13)
  static let inputFont = Font.custom("Roboto", size: 16)
  static let toggleTitleFont = Font.custom("Roboto-Medium", size: 14)
  static let toggleBodyFont = Font.custom("Roboto", size: 12)
  static let rowTitleFont = Font.custom("Roboto-Medium", size: 15)
  static let deletedBadgeFont = Font.custom("Roboto-Medium", size: 11)
  static let inUseBadgeFont = Font.custom("Roboto-Medium", size: 11)
  static let swipeActionFont = Font.custom("Roboto-Medium", size: 14)
  static let toastFont = Font.custom("Roboto-Bold", size: 15)
  static let toastButtonFont = Font.system(size: 15, weight: .heavy)

  static let toastHeight: CGFloat = 60
  static let toastCornerRadius: CGFloat = 14
  static let toastHorizontalPadding: CGFloat = 18
  static let toastButtonHeight: CGFloat = 36
  static let toastBorderWidth: CGFloat = 1.2
  static let toastBottomPadding: CGFloat = 18
}
