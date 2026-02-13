import SwiftData
import SwiftUI

struct NewEpisodeView: View {
  @EnvironmentObject var store: EpisodeStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @State private var selectedDate: Date?
  @State private var selectedReleaseDate: Date?
  @State private var selectedCategory: String?
  @State private var title = ""
  @State private var bodyText = ""
  @State private var personText = ""
  @State private var selectedPersons: [String] = []
  @State private var tagText = ""
  @State private var selectedTags: [String] = []
  @State private var projectText = ""
  @State private var selectedProjects: [String] = []
  @State private var emotionText = ""
  @State private var selectedEmotions: [String] = []
  @State private var placeText = ""
  @State private var selectedPlaceChip: String?
  @State private var showsDetails = true
  @State private var isKeyboardVisible = false

  // focus states to control inline suggestion visibility
  @State private var personFieldFocused = false
  @State private var projectFieldFocused = false
  @State private var emotionFieldFocused = false
  @State private var placeFieldFocused = false

  // sheet presented via item to avoid presentation race
  private struct SuggestionField: Identifiable {
    let id = UUID()
    let field: String
  }
  @State private var suggestionManagerField: SuggestionField? = nil

  private let maxPersons = 10
  private let maxTags = 10
  private let maxEmotions = 3
  private let maxProjects = 10
  private let categoryOptions = ["会話ネタ", "アイデア", "学び", "トラブル"]

  private var isSaveEnabled: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    GeometryReader { proxy in
      let contentWidth = min(
        NewEpisodeStyle.baseContentWidth, proxy.size.width - NewEpisodeStyle.horizontalPadding * 2)
      let horizontalPadding = max(
        NewEpisodeStyle.horizontalPadding, (proxy.size.width - contentWidth) / 2)
      let topPadding = max(0, NewEpisodeStyle.figmaTopInset - proxy.safeAreaInsets.top)
      let tabBarOffset = max(0, HomeStyle.tabBarHeight - 48)

      let actionBarHeight = NewEpisodeStyle.actionBarContentHeight + 1

      ScrollView {
        VStack(alignment: .leading, spacing: NewEpisodeStyle.sectionSpacing) {
          headerView
          formView
        }
        .padding(.top, topPadding)
        .padding(.bottom, actionBarHeight + tabBarOffset)
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
      .contentShape(Rectangle())
      .onTapGesture {
        hideKeyboard()
      }
      .background(Color.white)
      .overlay(alignment: .bottom) {
        if !isKeyboardVisible {
          actionBarView
            .offset(y: -tabBarOffset)
        }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .sheet(item: $suggestionManagerField) { field in
      SuggestionManagerView(repository: store.suggestionRepository, fieldType: field.field)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    #if canImport(UIKit)
      .onReceive(
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
      ) { _ in
        isKeyboardVisible = true
      }
      .onReceive(
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
      ) { _ in
        isKeyboardVisible = false
      }
    #endif
  }

  private var headerView: some View {
    HStack(spacing: 8) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(NewEpisodeStyle.headerText)
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
          .padding(8)
      }
      .buttonStyle(.plain)

      Text("エピソード登録")
        .font(NewEpisodeStyle.headerFont)
        .foregroundColor(NewEpisodeStyle.headerText)

      Spacer()
    }
    .frame(height: NewEpisodeStyle.headerHeight)
  }

  private var formView: some View {
    VStack(alignment: .leading, spacing: NewEpisodeStyle.sectionSpacing) {
      labeledDateField(title: "日付", required: true, placeholder: "日付を選択", date: $selectedDate)

      labeledField(title: "タイトル", required: true, placeholder: "タイトルを入力", text: $title)

      VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
        FieldLabel(title: "本文", required: true)
        EpisodeTextArea(placeholder: "思いついたエピソードを自由に入力してください", text: $bodyText)
      }

      labeledDateField(title: "解禁可能日", placeholder: "日付を選択", date: $selectedReleaseDate)

      VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
        FieldLabel(title: "種別")
        EpisodeDropdownField(
          placeholder: "種別を選択",
          selection: $selectedCategory,
          options: categoryOptions
        )
      }

      detailToggleButton

      if showsDetails {
        detailSection
      }
    }
  }

  private var detailToggleButton: some View {
    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        showsDetails.toggle()
      }
    } label: {
      HStack(spacing: 8) {
        Text(showsDetails ? "詳細を閉じる" : "詳細を開く")
          .font(NewEpisodeStyle.detailToggleFont)
          .foregroundColor(NewEpisodeStyle.chipText)
        Image(systemName: showsDetails ? "chevron.up" : "chevron.down")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(NewEpisodeStyle.chipText)
      }
      .frame(maxWidth: .infinity)
      .frame(height: NewEpisodeStyle.detailToggleHeight)
      .overlay(
        RoundedRectangle(cornerRadius: NewEpisodeStyle.inputCornerRadius)
          .stroke(NewEpisodeStyle.inputBorder, lineWidth: NewEpisodeStyle.inputBorderWidth)
      )
    }
    .buttonStyle(.plain)
  }

  private var detailSection: some View {
    VStack(alignment: .leading, spacing: NewEpisodeStyle.detailsSpacing) {
      VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
        FieldLabel(title: "企画名", limitText: "最大\(maxProjects)")
        EpisodeMultiChipInputField(
          placeholder: "企画名を入力してEnter",
          text: $projectText,
          selections: $selectedProjects,
          maxSelections: maxProjects,
          onCommit: { addProject(projectText) },
          onRemove: removeProject,
          isFocused: $projectFieldFocused
        )
        InlineSuggestionList(
          fieldType: "企画名", query: $projectText, maxItems: 3, isActive: projectFieldFocused,
          onSelect: { option in
            addProject(option)
            store.suggestionRepository.upsert(fieldType: "企画名", value: option)
          }
        )
        .environmentObject(store)
        .onReceive(NotificationCenter.default.publisher(for: .openSuggestionManagerSheet)) { note in
          if let field = note.object as? String, field == "企画名" {
            suggestionManagerField = SuggestionField(field: field)
          }
        }
      }

      VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
        FieldLabel(title: "人物（Who）", limitText: "最大\(maxPersons)")
        EpisodeMultiChipInputField(
          placeholder: "人物名を入力してEnter",
          text: $personText,
          selections: $selectedPersons,
          maxSelections: maxPersons,
          onCommit: { addPerson(personText) },
          onRemove: removePerson,
          isFocused: $personFieldFocused
        )
        InlineSuggestionList(
          fieldType: "人物", query: $personText, maxItems: 3, isActive: personFieldFocused,
          onSelect: { option in
            addPerson(option)
            store.suggestionRepository.upsert(fieldType: "人物", value: option)
          }
        )
        .environmentObject(store)
        .onReceive(NotificationCenter.default.publisher(for: .openSuggestionManagerSheet)) { note in
          if let field = note.object as? String, field == "人物" {
            suggestionManagerField = SuggestionField(field: field)
          }
        }
      }

      VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
        FieldLabel(title: "感情", limitText: "最大\(maxEmotions)")
        EpisodeMultiChipInputField(
          placeholder: "感情を選択または入力",
          text: $emotionText,
          selections: $selectedEmotions,
          maxSelections: maxEmotions,
          onCommit: { addEmotion(emotionText) },
          onRemove: removeEmotion,
          isFocused: $emotionFieldFocused
        )
        InlineSuggestionList(
          fieldType: "感情", query: $emotionText, maxItems: 3, isActive: emotionFieldFocused,
          onSelect: { option in
            addEmotion(option)
            store.suggestionRepository.upsert(fieldType: "感情", value: option)
          }
        )
        .environmentObject(store)
        .onReceive(NotificationCenter.default.publisher(for: .openSuggestionManagerSheet)) { note in
          if let field = note.object as? String, field == "感情" {
            suggestionManagerField = SuggestionField(field: field)
          }
        }
      }

      VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
        FieldLabel(title: "タグ", limitText: "最大\(maxTags)")
        EpisodeMultiChipInputField(
          placeholder: "タグを入力してEnter",
          text: $tagText,
          selections: $selectedTags,
          maxSelections: maxTags,
          onCommit: { addTag(tagText) },
          onRemove: removeTag
        )
      }

      VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
        FieldLabel(title: "場所")
        EpisodeChipInputField(
          placeholder: "場所を入力",
          text: $placeText,
          selection: $selectedPlaceChip,
          isFocused: $placeFieldFocused
        )
        InlineSuggestionList(
          fieldType: "場所", query: $placeText, maxItems: 3, isActive: placeFieldFocused,
          onSelect: { option in
            selectedPlaceChip = option
            placeText = option
            store.suggestionRepository.upsert(fieldType: "場所", value: option)
          }
        )
        .environmentObject(store)
        .onReceive(NotificationCenter.default.publisher(for: .openSuggestionManagerSheet)) { note in
          if let field = note.object as? String, field == "場所" {
            suggestionManagerField = SuggestionField(field: field)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func labeledField(
    title: String, required: Bool = false, placeholder: String, text: Binding<String>
  ) -> some View {
    VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
      FieldLabel(title: title, required: required)
      EpisodeTextField(placeholder: placeholder, text: text)
    }
  }

  @ViewBuilder
  private func labeledDateField(
    title: String, required: Bool = false, placeholder: String, date: Binding<Date?>
  ) -> some View {
    VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
      FieldLabel(title: title, required: required)
      EpisodeDateField(title: title, placeholder: placeholder, date: date)
    }
  }

  private func addPerson(_ name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard selectedPersons.count < maxPersons else {
      personText = ""
      return
    }
    if !selectedPersons.contains(trimmed) {
      selectedPersons.append(trimmed)
      store.suggestionRepository.upsert(fieldType: "人物", value: trimmed)
    }
    personText = ""
  }

  private func removePerson(_ name: String) {
    selectedPersons.removeAll { $0 == name }
  }

  private func addTag(_ value: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalized = normalizedTag(trimmed)
    guard let normalized else { return }
    guard selectedTags.count < maxTags else {
      tagText = ""
      return
    }
    if !selectedTags.contains(normalized) {
      selectedTags.append(normalized)
    }
    tagText = ""
  }

  private func removeTag(_ value: String) {
    selectedTags.removeAll { $0 == value }
  }

  private func normalizedTag(_ value: String) -> String? {
    guard !value.isEmpty else { return nil }
    if value.hasPrefix("#") { return value }
    return "#\(value)"
  }

  private func addProject(_ value: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard selectedProjects.count < maxProjects else {
      projectText = ""
      return
    }
    if !selectedProjects.contains(trimmed) {
      selectedProjects.append(trimmed)
      store.suggestionRepository.upsert(fieldType: "企画名", value: trimmed)
    }
    projectText = ""
  }

  private func removeProject(_ value: String) {
    selectedProjects.removeAll { $0 == value }
  }

  private func addEmotion(_ value: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard selectedEmotions.count < maxEmotions else {
      emotionText = ""
      return
    }
    if !selectedEmotions.contains(trimmed) {
      selectedEmotions.append(trimmed)
      store.suggestionRepository.upsert(fieldType: "感情", value: trimmed)
    }
    emotionText = ""
  }

  private func removeEmotion(_ value: String) {
    selectedEmotions.removeAll { $0 == value }
  }

  private var actionBarView: some View {
    VStack(spacing: 0) {
      Rectangle()
        .fill(HomeStyle.outline)
        .frame(height: 1)

      HStack(spacing: 24) {
        Button("登録") {
          save()
        }
        .font(NewEpisodeStyle.actionButtonFont)
        .foregroundColor(NewEpisodeStyle.primaryButtonText)
        .frame(width: NewEpisodeStyle.actionButtonWidth, height: NewEpisodeStyle.actionButtonHeight)
        .background(NewEpisodeStyle.primaryButtonFill)
        .clipShape(Capsule())
        .disabled(!isSaveEnabled)
        .opacity(isSaveEnabled ? 1 : 0.6)

        Button("キャンセル") {
          dismiss()
        }
        .font(NewEpisodeStyle.actionButtonFont)
        .foregroundColor(NewEpisodeStyle.secondaryButtonText)
        .frame(width: NewEpisodeStyle.actionButtonWidth, height: NewEpisodeStyle.actionButtonHeight)
        .background(
          Capsule()
            .stroke(NewEpisodeStyle.secondaryButtonBorder, lineWidth: 1)
        )
      }
      .frame(height: NewEpisodeStyle.actionBarContentHeight, alignment: .center)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.horizontal, 24)
    }
    .background(NewEpisodeStyle.actionBarBackground)
  }

  private func save() {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty, !trimmedBody.isEmpty else { return }
    let trimmedType = (selectedCategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let type = trimmedType.isEmpty ? nil : trimmedType
    let trimmedPlace = (selectedPlaceChip ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    _ = modelContext.createEpisode(
      title: trimmedTitle,
      body: trimmedBody,
      date: selectedDate ?? Date(),
      unlockDate: selectedReleaseDate,
      type: type,
      tags: selectedTags,
      persons: selectedPersons,
      projects: selectedProjects,
      emotions: selectedEmotions,
      place: trimmedPlace.isEmpty ? nil : trimmedPlace
    )
    dismiss()
  }
}

private enum NewEpisodeStyle {
  static let baseContentWidth: CGFloat = 360
  static let horizontalPadding: CGFloat = 21
  static let figmaTopInset: CGFloat = 61
  static let sectionSpacing: CGFloat = 16
  static let fieldSpacing: CGFloat = 8
  static let detailsSpacing: CGFloat = 24
  static let chipRowSpacing: CGFloat = 8
  static let chipSpacing: CGFloat = 8
  static let inputHeight: CGFloat = 41
  static let textAreaHeight: CGFloat = 200
  static let inputCornerRadius: CGFloat = 10
  static let inputBorderWidth: CGFloat = 0.66
  static let detailToggleHeight: CGFloat = 49
  static let chipHeightLarge: CGFloat = 36
  static let chipHeightSmall: CGFloat = 28
  static let headerHeight: CGFloat = 48
  static let actionButtonHeight: CGFloat = 48
  static let actionButtonWidth: CGFloat = 120
  static let actionBarContentHeight: CGFloat = 72
  static let selectedChipHeight: CGFloat = 28

  static let labelText = Color(hex: "4A5565")
  static let requiredText = Color(hex: "FB2C36")
  static let placeholderText = Color.black.opacity(0.5)
  static let inputText = Color(hex: "0A0A0A")
  static let inputBorder = Color(hex: "D1D5DC")
  static let chipFill = Color(hex: "F3F4F6")
  static let chipText = Color(hex: "364153")
  static let limitText = Color(hex: "9CA3AF")
  static let headerText = Color(hex: "2A2525")

  static let primaryButtonFill = HomeStyle.fabRed
  static let primaryButtonText = Color.white
  static let secondaryButtonBorder = Color(hex: "CAC4D0")
  static let secondaryButtonText = Color(hex: "49454F")
  static let actionBarBackground = Color.white

  static let labelFont = Font.custom("Roboto-Medium", size: 14)
  static let inputFont = Font.custom("Roboto", size: 16)
  static let headerFont = Font.custom("Roboto-Medium", size: 20)
  static let detailToggleFont = Font.custom("Roboto-Medium", size: 16)
  static let actionButtonFont = Font.system(size: 16, weight: .bold)

  static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateFormat = "yyyy/MM/dd"
    return formatter
  }()
}

private struct FieldLabel: View {
  let title: String
  var required: Bool = false
  var limitText: String? = nil

  var body: some View {
    HStack(spacing: 2) {
      Text(title)
        .font(NewEpisodeStyle.labelFont)
        .foregroundColor(NewEpisodeStyle.labelText)
      if required {
        Text("*")
          .font(NewEpisodeStyle.labelFont)
          .foregroundColor(NewEpisodeStyle.requiredText)
      }
      if let limitText {
        Text("（\(limitText)）")
          .font(NewEpisodeStyle.labelFont)
          .foregroundColor(NewEpisodeStyle.limitText)
      }
    }
  }
}

private struct EpisodeTextField: View {
  let placeholder: String
  @Binding var text: String

  var body: some View {
    TextField(
      "", text: $text, prompt: Text(placeholder).foregroundColor(NewEpisodeStyle.placeholderText)
    )
    .font(NewEpisodeStyle.inputFont)
    .foregroundColor(NewEpisodeStyle.inputText)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(height: NewEpisodeStyle.inputHeight)
    .background(
      RoundedRectangle(cornerRadius: NewEpisodeStyle.inputCornerRadius)
        .stroke(NewEpisodeStyle.inputBorder, lineWidth: NewEpisodeStyle.inputBorderWidth)
    )
  }
}

private struct EpisodeChipInputField: View {
  let placeholder: String
  @Binding var text: String
  @Binding var selection: String?
  var isFocused: Binding<Bool>? = nil

  @FocusState private var focused: Bool

  var body: some View {
    HStack(spacing: 6) {
      if let selection {
        SelectedChip(title: selection) {
          self.selection = nil
          text = ""
        }
      } else {
        TextField(
          "", text: $text,
          prompt: Text(placeholder).foregroundColor(NewEpisodeStyle.placeholderText)
        )
        .font(NewEpisodeStyle.inputFont)
        .foregroundColor(NewEpisodeStyle.inputText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .focused($focused)
        .onChange(of: focused) { _, newValue in
          isFocused?.wrappedValue = newValue
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(height: NewEpisodeStyle.inputHeight)
    .background(
      RoundedRectangle(cornerRadius: NewEpisodeStyle.inputCornerRadius)
        .stroke(NewEpisodeStyle.inputBorder, lineWidth: NewEpisodeStyle.inputBorderWidth)
    )
  }
}

private struct EpisodeDropdownField: View {
  let placeholder: String
  @Binding var selection: String?
  let options: [String]

  private var displayText: String {
    selection ?? placeholder
  }

  private var displayColor: Color {
    selection == nil ? NewEpisodeStyle.placeholderText : NewEpisodeStyle.inputText
  }

  var body: some View {
    Menu {
      ForEach(options, id: \.self) { option in
        Button(option) {
          selection = option
        }
      }
    } label: {
      HStack {
        Text(displayText)
          .font(NewEpisodeStyle.inputFont)
          .foregroundColor(displayColor)
        Spacer(minLength: 0)
        Image(systemName: "chevron.down")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(NewEpisodeStyle.chipText)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(height: NewEpisodeStyle.inputHeight)
      .background(
        RoundedRectangle(cornerRadius: NewEpisodeStyle.inputCornerRadius)
          .stroke(NewEpisodeStyle.inputBorder, lineWidth: NewEpisodeStyle.inputBorderWidth)
      )
    }
    .buttonStyle(.plain)
  }
}

private struct FlowLayout: Layout {
  let spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .greatestFiniteMagnitude
    var currentX: CGFloat = 0
    var totalHeight: CGFloat = 0
    var lineHeight: CGFloat = 0
    var maxLineWidth: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if currentX + size.width > maxWidth, currentX > 0 {
        totalHeight += lineHeight + spacing
        maxLineWidth = max(maxLineWidth, currentX - spacing)
        currentX = 0
        lineHeight = 0
      }
      currentX += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }

    totalHeight += lineHeight
    maxLineWidth = max(maxLineWidth, currentX - spacing)

    let width = proposal.width ?? maxLineWidth
    return CGSize(width: width, height: totalHeight)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var currentX = bounds.minX
    var currentY = bounds.minY
    var lineHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if currentX + size.width > bounds.maxX, currentX > bounds.minX {
        currentX = bounds.minX
        currentY += lineHeight + spacing
        lineHeight = 0
      }
      subview.place(
        at: CGPoint(x: currentX, y: currentY),
        proposal: ProposedViewSize(width: size.width, height: size.height))
      currentX += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }
  }
}

private struct EpisodeMultiChipInputField: View {
  let placeholder: String
  @Binding var text: String
  @Binding var selections: [String]
  let maxSelections: Int
  let onCommit: () -> Void
  let onRemove: (String) -> Void
  var isFocused: Binding<Bool>? = nil

  @FocusState private var focused: Bool

  var body: some View {
    let isAtLimit = selections.count >= maxSelections
    let promptText = selections.isEmpty ? placeholder : ""

    FlowLayout(spacing: 6) {
      ForEach(selections, id: \.self) { item in
        SelectedChip(title: item) {
          onRemove(item)
        }
      }
      if !isAtLimit {
        TextField(
          "", text: $text, prompt: Text(promptText).foregroundColor(NewEpisodeStyle.placeholderText)
        )
        .font(NewEpisodeStyle.inputFont)
        .foregroundColor(NewEpisodeStyle.inputText)
        .frame(minWidth: 80, alignment: .leading)
        .focused($focused)
        .onChange(of: focused) { _, newValue in
          isFocused?.wrappedValue = newValue
        }
        .onSubmit {
          onCommit()
          focused = false
          isFocused?.wrappedValue = false
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(minHeight: NewEpisodeStyle.inputHeight, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: NewEpisodeStyle.inputCornerRadius)
        .stroke(NewEpisodeStyle.inputBorder, lineWidth: NewEpisodeStyle.inputBorderWidth)
    )
  }
}

private struct EpisodeDateField: View {
  let title: String
  let placeholder: String
  @Binding var date: Date?

  @State private var showsPicker = false
  @State private var tempDate = Date()

  private var displayText: String {
    guard let date else { return placeholder }
    return NewEpisodeStyle.dateFormatter.string(from: date)
  }

  private var displayColor: Color {
    date == nil ? NewEpisodeStyle.placeholderText : NewEpisodeStyle.inputText
  }

  var body: some View {
    Button {
      tempDate = date ?? Date()
      showsPicker = true
    } label: {
      HStack {
        Text(displayText)
          .font(NewEpisodeStyle.inputFont)
          .foregroundColor(displayColor)
        Spacer(minLength: 0)
        Image(systemName: "calendar")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(NewEpisodeStyle.chipText)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(height: NewEpisodeStyle.inputHeight)
      .background(
        RoundedRectangle(cornerRadius: NewEpisodeStyle.inputCornerRadius)
          .stroke(NewEpisodeStyle.inputBorder, lineWidth: NewEpisodeStyle.inputBorderWidth)
      )
    }
    .buttonStyle(.plain)
    .sheet(isPresented: $showsPicker) {
      NavigationStack {
        VStack {
          DatePicker("", selection: $tempDate, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(.horizontal, 8)

          Button("決定") {
            date = tempDate
            showsPicker = false
          }
          .font(NewEpisodeStyle.actionButtonFont)
          .foregroundColor(NewEpisodeStyle.primaryButtonText)
          .padding(.horizontal, 24)
          .frame(height: 48)
          .background(NewEpisodeStyle.primaryButtonFill)
          .clipShape(Capsule())
          .padding(.bottom, 12)
        }
        .navigationTitle(title)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("閉じる") {
              showsPicker = false
            }
          }
        }
      }
    }
  }
}

private struct EpisodeTextArea: View {
  let placeholder: String
  @Binding var text: String

  var body: some View {
    ZStack(alignment: .topLeading) {
      if text.isEmpty {
        Text(placeholder)
          .font(NewEpisodeStyle.inputFont)
          .foregroundColor(NewEpisodeStyle.placeholderText)
          .padding(.horizontal, 12)
          .padding(.vertical, 12)
      }

      TextEditor(text: $text)
        .font(NewEpisodeStyle.inputFont)
        .foregroundColor(NewEpisodeStyle.inputText)
        .padding(8)
        .scrollContentBackground(.hidden)
    }
    .frame(height: NewEpisodeStyle.textAreaHeight)
    .background(
      RoundedRectangle(cornerRadius: NewEpisodeStyle.inputCornerRadius)
        .stroke(NewEpisodeStyle.inputBorder, lineWidth: NewEpisodeStyle.inputBorderWidth)
    )
  }
}

private struct EpisodeChip: View {
  let title: String
  let height: CGFloat

  var body: some View {
    Text(title)
      .font(NewEpisodeStyle.labelFont)
      .foregroundColor(NewEpisodeStyle.chipText)
      .padding(.horizontal, 14)
      .frame(height: height)
      .background(NewEpisodeStyle.chipFill)
      .clipShape(Capsule())
  }
}

private struct SelectedChip: View {
  let title: String
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      Text(title)
        .font(NewEpisodeStyle.labelFont)
        .foregroundColor(NewEpisodeStyle.chipText)
      Button(action: onRemove) {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(NewEpisodeStyle.chipText)
          .frame(width: 16, height: 16)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 12)
    .frame(height: NewEpisodeStyle.selectedChipHeight)
    .background(NewEpisodeStyle.chipFill)
    .clipShape(Capsule())
  }
}

struct NewEpisodeView_Previews: PreviewProvider {
  static var previews: some View {
    NewEpisodeView()
      .environmentObject(EpisodeStore())
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
