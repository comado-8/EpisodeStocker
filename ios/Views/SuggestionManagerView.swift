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
  @State private var undoToastTask: Task<Void, Never>?
  private let selectedValues: [String]
  private let selectionLimit: Int?
  private let onSelect: ((String) -> Void)?
  private let onDeselect: ((String) -> Void)?
  private let repository: SuggestionRepository
  private let fieldType: SuggestionFieldType

  init(
    repository: SuggestionRepository,
    fieldType: String,
    selectedValues: [String] = [],
    selectionLimit: Int? = nil,
    onSelect: ((String) -> Void)? = nil,
    onDeselect: ((String) -> Void)? = nil
  ) {
    self.repository = repository
    let resolvedFieldType = SuggestionFieldType(fieldType)
    self.fieldType = resolvedFieldType
    _vm = StateObject(
      wrappedValue: SuggestionManagerViewModel(repository: repository, fieldType: resolvedFieldType)
    )
    self.selectedValues = selectedValues
    self.selectionLimit = selectionLimit
    self.onSelect = onSelect
    self.onDeselect = onDeselect
  }

  private var normalizedSelectedValues: Set<String> {
    Set(
      selectedValues.compactMap {
        SuggestionRepositoryPrimer.normalizedValue($0, fieldType: fieldType)
      })
  }

  private var selectedCount: Int {
    normalizedSelectedValues.count
  }

  private var isAtSelectionLimit: Bool {
    guard let selectionLimit else { return false }
    return selectedCount >= selectionLimit
  }

  private var selectionLimitText: String {
    guard let selectionLimit else { return "" }
    return "（最大\(selectionLimit)件）"
  }

  var body: some View {
    NavigationStack {
      ZStack {
        Color.white.ignoresSafeArea()

        VStack(spacing: SuggestionManagerStyle.sectionSpacing) {
          controlsCard

          let usageCounts = usageCountsByNormalizedValue()
          List {
            ForEach(vm.suggestions) { suggestion in
              let activeCount = activeUsageCount(for: suggestion.value, usageCounts: usageCounts)
              let isDeletionProtected = isDeletionProtectedSuggestion(
                suggestion: suggestion,
                activeUsageCount: activeCount
              )
              let normalized = SuggestionRepositoryPrimer.normalizedValue(
                suggestion.value,
                fieldType: fieldType
              )
              let isSelected =
                normalized.map { normalizedSelectedValues.contains($0) } ?? false
              let isSelectionBlocked = !isSelected && isAtSelectionLimit
              SuggestionRow(
                suggestion: suggestion,
                isDeletionProtected: isDeletionProtected,
                protectedUsageCount: activeCount,
                isSelected: isSelected,
                isSelectionBlocked: isSelectionBlocked
              )
                .contentShape(Rectangle())
                .onTapGesture {
                  guard !suggestion.isDeleted else { return }
                  if isSelected {
                    onDeselect?(suggestion.value)
                    return
                  }
                  guard !isSelectionBlocked else { return }
                  onSelect?(suggestion.value)
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
                      undoToastTask?.cancel()
                      showsUndoToast = true
                      undoToastTask = Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                          showsUndoToast = false
                        }
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
      .navigationBarTitleDisplayMode(.large)
      .toolbar(.visible, for: .navigationBar)
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
              undoToastTask?.cancel()
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
    .onDisappear {
      undoToastTask?.cancel()
      undoToastTask = nil
      NotificationCenter.default.post(
        name: .suggestionManagerSheetDidDismiss,
        object: fieldType.label
      )
    }
  }

  private var controlsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("対象: \(vm.title)\(selectionLimitText)")
        .font(SuggestionManagerStyle.subheaderFont)
        .foregroundColor(SuggestionManagerStyle.subheaderText)

      if isAtSelectionLimit, let selectionLimit {
        HStack(spacing: 6) {
          Image(systemName: "exclamationmark.circle.fill")
            .font(.system(size: 13, weight: .semibold))
          Text("最大\(selectionLimit)件に到達しています")
            .font(SuggestionManagerStyle.warningFont)
        }
        .foregroundColor(SuggestionManagerStyle.warningText)
      }

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
    SuggestionRepositoryPrimer.prime(
      repository: repository,
      fieldType: fieldType,
      values: existingValuesForField()
    )
  }

  private func existingValuesForField() -> [String] {
    switch fieldType {
    case .person:
      return persons.map(\.name)
    case .project:
      return projects.map(\.name)
    case .emotion:
      return emotions.map(\.name)
    case .place:
      return places.map(\.name)
    case .tag:
      return tags.map { tag in
        guard let normalized = EpisodePersistence.normalizeTagName(tag.name)?.name else {
          return ""
        }
        return "#\(normalized)"
      }
    case .unknown:
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
    guard fieldType.protectsUsedEntriesFromDeletion else { return false }
    return activeUsageCount > 0
  }

  private func usageCountsByNormalizedValue() -> [String: Int] {
    guard fieldType.supportsUsageCount else { return [:] }
    var counts: [String: Int] = [:]
    for episode in episodes {
      var values = Set<String>()
      switch fieldType {
      case .person:
        values = Set(episode.persons.compactMap { normalizedValueForField($0.name, fieldType: .person) })
      case .project:
        values = Set(episode.projects.compactMap { normalizedValueForField($0.name, fieldType: .project) })
      case .place:
        values = Set(episode.places.compactMap { normalizedValueForField($0.name, fieldType: .place) })
      case .tag:
        values = Set(episode.tags.compactMap { normalizedValueForField("#\($0.name)", fieldType: .tag) })
      case .emotion, .unknown:
        values = []
      }
      for value in values {
        counts[value, default: 0] += 1
      }
    }
    return counts
  }

  private func activeUsageCount(for value: String, usageCounts: [String: Int]) -> Int {
    guard let normalizedValue = normalizedValueForField(value, fieldType: fieldType) else {
      return 0
    }
    return usageCounts[normalizedValue, default: 0]
  }

  private func normalizedValueForField(_ value: String, fieldType: SuggestionFieldType) -> String? {
    switch fieldType {
    case .tag:
      return EpisodePersistence.normalizeTagName(value)?.normalized
    case .person, .project, .emotion, .place:
      return EpisodePersistence.normalizeName(value)?.normalized
    case .unknown:
      return nil
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
  let isSelected: Bool
  let isSelectionBlocked: Bool

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
      if isSelected {
        Label("入力済み", systemImage: "checkmark")
          .font(SuggestionManagerStyle.selectedBadgeFont)
          .foregroundColor(SuggestionManagerStyle.selectedBadgeText)
          .padding(.horizontal, 8)
          .frame(height: 20)
          .background(
            Capsule()
              .fill(SuggestionManagerStyle.selectedBadgeFill)
              .overlay(
                Capsule()
                  .stroke(SuggestionManagerStyle.selectedBadgeBorder, lineWidth: 1)
              )
          )
      } else if suggestion.isDeleted {
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
        .fill(isSelected ? SuggestionManagerStyle.selectedRowFill : SuggestionManagerStyle.rowFill)
        .overlay(
          RoundedRectangle(cornerRadius: SuggestionManagerStyle.rowCornerRadius, style: .continuous)
            .stroke(
              isSelected ? SuggestionManagerStyle.selectedRowBorder : SuggestionManagerStyle.rowBorder,
              lineWidth: 1
            )
        )
    )
    .opacity(isSelectionBlocked ? 0.52 : 1)
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
  static let inputText = HomeStyle.textInput
  static let inputIcon = Color(hex: "6B7280")
  static let subheaderText = HomeStyle.textSecondary
  static let toggleTitleText = HomeStyle.textPrimary
  static let toggleBodyText = HomeStyle.textSecondary
  static let toggleTint = HomeStyle.fabRed

  static let rowFill = Color(hex: "FFFFFF")
  static let rowBorder = Color(hex: "E5E7EB")
  static let rowTitleText = HomeStyle.textPrimary
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
  static let selectedBadgeFill = Color(hex: "E5E7EB")
  static let selectedBadgeBorder = Color(hex: "CBD3DF")
  static let selectedBadgeText = Color(hex: "4A5565")
  static let selectedRowFill = Color(hex: "F7F8FA")
  static let selectedRowBorder = Color(hex: "D7DDE6")
  static let warningText = HomeStyle.fabRed

  static let toastFill = Color(hex: "FFF4F4")
  static let toastBorder = HomeStyle.fabRed.opacity(0.32)
  static let toastText = HomeStyle.textPrimary
  static let toastButtonText = Color.white
  static let toastButtonFill = HomeStyle.fabRed

  static let headerCloseFont = AppTypography.subtextEmphasis
  static let subheaderFont = AppTypography.subtext
  static let inputFont = AppTypography.body
  static let toggleTitleFont = AppTypography.subtextEmphasis
  static let toggleBodyFont = AppTypography.subtext
  static let rowTitleFont = AppTypography.bodyEmphasis
  static let deletedBadgeFont = AppTypography.meta
  static let inUseBadgeFont = AppTypography.meta
  static let selectedBadgeFont = AppTypography.meta
  static let swipeActionFont = AppTypography.subtextEmphasis
  static let toastFont = AppTypography.subtextEmphasis
  static let toastButtonFont = AppTypography.subtextEmphasis
  static let warningFont = AppTypography.subtextEmphasis

  static let toastHeight: CGFloat = 60
  static let toastCornerRadius: CGFloat = 14
  static let toastHorizontalPadding: CGFloat = 18
  static let toastButtonHeight: CGFloat = 36
  static let toastBorderWidth: CGFloat = 1.2
  static let toastBottomPadding: CGFloat = 18
}
