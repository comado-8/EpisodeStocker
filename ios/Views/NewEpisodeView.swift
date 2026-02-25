import SwiftData
import SwiftUI

struct NewEpisodeView: View {
  @EnvironmentObject var store: EpisodeStore
  @EnvironmentObject private var router: AppRouter
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(filter: #Predicate<Tag> { $0.isSoftDeleted == false })
  private var allTags: [Tag]

  @State private var selectedDate: Date? = Date()
  @State private var selectedReleaseDate: Date?
  @State private var title = ""
  @State private var bodyText = ""
  @State private var personText = ""
  @State private var selectedPersons: [String] = []
  @State private var tagText = ""
  @State private var selectedTags: [String] = []
  @State private var projectText = ""
  @State private var selectedProjects: [String] = []
  @State private var selectedEmotions: [String] = []
  @State private var placeText = ""
  @State private var selectedPlaceChip: String?
  @State private var showsDetails = true
  @State private var showsTagSelectionSheet = false
  @State private var isKeyboardVisible = false
  @State private var showsDiscardAlert = false
  @State private var pendingAction: NewEpisodePendingAction?
  @State private var initialReleaseDate: Date?
  @State private var hasCapturedInitialDraftState = false

  // focus states to control inline suggestion visibility
  @State private var personFieldFocused = false
  @State private var projectFieldFocused = false
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
  private let maxProjects = 3

  private var isSaveEnabled: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !isBodyOverLimit
      && !isPersonNameOverLimit
      && !isProjectNameOverLimit
      && !isPlaceNameOverLimit
  }

  private var bodyCharacterCountText: String {
    "\(bodyText.count) / \(EpisodePersistence.bodyCharacterLimit)"
  }

  private var isBodyOverLimit: Bool {
    bodyText.count > EpisodePersistence.bodyCharacterLimit
  }

  private var bodyLengthValidationMessage: String? {
    guard isBodyOverLimit else { return nil }
    return "本文は\(EpisodePersistence.bodyCharacterLimit)文字以内で入力してください"
  }

  private var isPersonNameOverLimit: Bool {
    personText.trimmingCharacters(in: .whitespacesAndNewlines).count
      > EpisodePersistence.personNameCharacterLimit
  }

  private var isProjectNameOverLimit: Bool {
    projectText.trimmingCharacters(in: .whitespacesAndNewlines).count
      > EpisodePersistence.projectNameCharacterLimit
  }

  private var isPlaceNameOverLimit: Bool {
    placeText.trimmingCharacters(in: .whitespacesAndNewlines).count
      > EpisodePersistence.placeNameCharacterLimit
  }

  private var personValidationErrorMessage: String? {
    guard isPersonNameOverLimit else { return nil }
    return "人物は\(EpisodePersistence.personNameCharacterLimit)文字以内で入力してください"
  }

  private var projectValidationErrorMessage: String? {
    guard isProjectNameOverLimit else { return nil }
    return "企画名は\(EpisodePersistence.projectNameCharacterLimit)文字以内で入力してください"
  }

  private var placeValidationErrorMessage: String? {
    guard isPlaceNameOverLimit else { return nil }
    return "場所は\(EpisodePersistence.placeNameCharacterLimit)文字以内で入力してください"
  }

  private var hasUnsavedDraftChanges: Bool {
    let releaseDateChanged = selectedReleaseDate != initialReleaseDate
    let hasTypedContent =
      !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !personText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !tagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !projectText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !placeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let hasSelectedItems =
      !selectedPersons.isEmpty
      || !selectedTags.isEmpty
      || !selectedProjects.isEmpty
      || !selectedEmotions.isEmpty
      || selectedPlaceChip != nil
      || releaseDateChanged
    return hasTypedContent || hasSelectedItems
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

      ZStack {
        ScrollView {
          VStack(alignment: .leading, spacing: NewEpisodeStyle.sectionSpacing) {
            headerView
            formView
          }
          .padding(.top, topPadding)
          .padding(.bottom, actionBarHeight + tabBarOffset + 8)
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
              .overlay(alignment: .bottom) {
                Rectangle()
                  .fill(NewEpisodeStyle.actionBarBackground)
                  .frame(height: NewEpisodeStyle.actionBarSeamOverlap)
                  .offset(y: NewEpisodeStyle.actionBarSeamOverlap)
              }
              .offset(y: -tabBarOffset)
          }
        }

        if showsDiscardAlert {
          discardAlertView
        }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .sheet(item: $suggestionManagerField) { field in
      SuggestionManagerView(
        repository: store.suggestionRepository,
        fieldType: field.field,
        onSelect: { value in
          applySuggestionSelection(fieldType: field.field, value: value)
        }
      )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.white)
    }
    .sheet(isPresented: $showsTagSelectionSheet) {
      RegisteredTagSelectionSheet(
        tags: registeredTagSuggestions,
        selectedTags: selectedTags,
        onSelect: { value in
          addTag(value)
        },
        style: NewEpisodeStyle.registeredTagSelectionSheetStyle
      )
      .presentationDetents([.medium, .large])
      .presentationDragIndicator(.visible)
      .presentationBackground(Color.white)
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
      .onChange(of: tagText) { _, newValue in
        let normalized = EpisodePersistence.normalizeTagInputWhileEditing(newValue)
        if normalized != newValue {
          tagText = normalized
        }
      }
      .onChange(of: hasUnsavedDraftChanges) { _, _ in
        syncUnsavedDraftStateToRouter()
      }
      .onChange(of: router.pendingRootTabSwitch) { _, requestedTab in
        handlePendingRootTabSwitch(requestedTab)
      }
      .onAppear {
        if !hasCapturedInitialDraftState {
          initialReleaseDate = selectedReleaseDate
          hasCapturedInitialDraftState = true
        }
        syncUnsavedDraftStateToRouter()
      }
      .onDisappear {
        router.hasUnsavedNewEpisodeChanges = false
      }
      .edgeSwipeBack {
        requestClose()
      }
  }

  private var headerView: some View {
    HStack(spacing: 8) {
      Button {
        requestClose()
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
      labeledDateField(
        title: "日付",
        required: true,
        placeholder: "日付を選択",
        date: $selectedDate
      )

      labeledField(title: "タイトル", required: true, placeholder: "タイトルを入力", text: $title)

      VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
        HStack(spacing: 8) {
          FieldLabel(title: "本文")
          Spacer(minLength: 0)
          Text(bodyCharacterCountText)
            .font(NewEpisodeStyle.counterFont)
            .foregroundColor(NewEpisodeStyle.limitText)
        }
        EpisodeTextArea(
          placeholder: "思いついたエピソードを自由に入力してください",
          text: $bodyText
        )
        if let bodyLengthValidationMessage {
          Text(bodyLengthValidationMessage)
            .font(NewEpisodeStyle.validationFont)
            .foregroundColor(NewEpisodeStyle.validationText)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
        labeledDateField(
          title: "解禁可能日",
          placeholder: "日付を選択",
          date: $selectedReleaseDate,
          allowsClearing: true
        )
        Text("未設定の場合は「解禁前」に表示されます。")
          .font(NewEpisodeStyle.tagGuideFont)
          .foregroundColor(NewEpisodeStyle.tagGuideText)
          .fixedSize(horizontal: false, vertical: true)
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
      .background(
        RoundedRectangle(cornerRadius: NewEpisodeStyle.inputCornerRadius)
          .fill(NewEpisodeStyle.detailToggleFill)
      )
      .overlay(
        RoundedRectangle(cornerRadius: NewEpisodeStyle.inputCornerRadius)
          .stroke(
            NewEpisodeStyle.detailToggleBorder,
            lineWidth: NewEpisodeStyle.detailToggleBorderWidth
          )
      )
    }
    .buttonStyle(.plain)
    .padding(.top, NewEpisodeStyle.detailToggleTopSpacing)
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
        if let projectValidationErrorMessage {
          Text(projectValidationErrorMessage)
            .font(NewEpisodeStyle.validationFont)
            .foregroundColor(NewEpisodeStyle.validationText)
            .fixedSize(horizontal: false, vertical: true)
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
        if let tagValidationErrorMessage {
          Text(tagValidationErrorMessage)
            .font(NewEpisodeStyle.validationFont)
            .foregroundColor(NewEpisodeStyle.validationText)
            .fixedSize(horizontal: false, vertical: true)
        }
        Text(TagInputConstants.guideText)
          .font(NewEpisodeStyle.tagGuideFont)
          .foregroundColor(NewEpisodeStyle.tagGuideText)
          .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 8) {
          Button {
            showsTagSelectionSheet = true
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "tag")
                .font(.system(size: 12, weight: .semibold))
              Text("登録タグ選択")
            }
            .font(NewEpisodeStyle.tagGuideFont)
            .foregroundColor(HomeStyle.fabRed)
            .padding(.horizontal, 10)
            .frame(height: NewEpisodeStyle.tagGuideActionHeight)
            .background(HomeStyle.fabRed.opacity(0.08))
            .overlay(
              Capsule()
                .stroke(HomeStyle.fabRed.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NewEpisodeStyle.chipSpacing) {
              ForEach(
                TagInputHelpers.filteredSuggestions(
                  query: tagText,
                  selectedTags: selectedTags,
                  registeredTagSuggestions: registeredTagSuggestions
                ),
                id: \.self
              ) { tag in
                Button {
                  addTag(tag)
                } label: {
                  EpisodeChip(title: tag, height: NewEpisodeStyle.chipHeightSmall)
                }
                .buttonStyle(.plain)
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
        FieldLabel(title: "感情", limitText: "最大\(maxEmotions)")
        emotionPresetSelector
      }

      VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
        FieldLabel(title: "人物", limitText: "最大\(maxPersons)")
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
        if let personValidationErrorMessage {
          Text(personValidationErrorMessage)
            .font(NewEpisodeStyle.validationFont)
            .foregroundColor(NewEpisodeStyle.validationText)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
        FieldLabel(title: "場所")
        EpisodeChipInputField(
          placeholder: "場所を入力",
          text: $placeText,
          selection: $selectedPlaceChip,
          isFocused: $placeFieldFocused,
          onSubmit: { commitPlace(placeText) }
        )
        InlineSuggestionList(
          fieldType: "場所", query: $placeText, maxItems: 3, isActive: placeFieldFocused,
          onSelect: { option in
            commitPlace(option)
          }
        )
        .environmentObject(store)
        .onReceive(NotificationCenter.default.publisher(for: .openSuggestionManagerSheet)) { note in
          if let field = note.object as? String, field == "場所" {
            suggestionManagerField = SuggestionField(field: field)
          }
        }
        if let placeValidationErrorMessage {
          Text(placeValidationErrorMessage)
            .font(NewEpisodeStyle.validationFont)
            .foregroundColor(NewEpisodeStyle.validationText)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(.bottom, NewEpisodeStyle.detailBottomScrollPadding)
  }

  private var emotionPresetSelector: some View {
    FlowLayout(spacing: NewEpisodeStyle.chipSpacing) {
      ForEach(emotionChipOptions, id: \.self) { option in
        let selected = selectedEmotions.contains(option)
        let disabled = !selected && selectedEmotions.count >= maxEmotions
        Button {
          toggleEmotion(option)
        } label: {
          EmotionPresetChip(title: option, isSelected: selected)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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
    title: String,
    required: Bool = false,
    placeholder: String,
    date: Binding<Date?>,
    allowsClearing: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: NewEpisodeStyle.fieldSpacing) {
      FieldLabel(title: title, required: required)
      EpisodeDateField(
        title: title,
        placeholder: placeholder,
        date: date,
        allowsClearing: allowsClearing
      )
    }
  }

  private func addPerson(_ name: String) {
    guard let trimmed = normalizedPersonName(name) else { return }
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
    guard let normalized = normalizedTag(value) else { return }
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
    guard let normalized = EpisodePersistence.validateTagNameInput(value).normalizedName else {
      return nil
    }
    return "#\(normalized)"
  }

  private var registeredTagSuggestions: [String] {
    allTags
      .sorted { $0.updatedAt > $1.updatedAt }
      .compactMap(displayTagName)
  }

  private func displayTagName(_ tag: Tag) -> String? {
    guard let normalized = EpisodePersistence.normalizeTagName(tag.name)?.name else {
      return nil
    }
    return "#\(normalized)"
  }

  private var tagValidationErrorMessage: String? {
    TagInputHelpers.validationMessage(for: tagText)
  }

  private func addProject(_ value: String) {
    guard let trimmed = normalizedProjectName(value) else { return }
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
    guard EpisodePersistence.emotionPresetOptions.contains(trimmed) else { return }
    guard selectedEmotions.count < maxEmotions else {
      return
    }
    if !selectedEmotions.contains(trimmed) {
      selectedEmotions.append(trimmed)
    }
  }

  private func toggleEmotion(_ value: String) {
    if selectedEmotions.contains(value) {
      removeEmotion(value)
    } else {
      addEmotion(value)
    }
  }

  private func removeEmotion(_ value: String) {
    selectedEmotions.removeAll { $0 == value }
  }

  private var emotionChipOptions: [String] {
    let extraSelections = selectedEmotions.filter { selected in
      !EpisodePersistence.emotionPresetOptions.contains(selected)
    }
    return EpisodePersistence.emotionPresetOptions + extraSelections
  }

  private func commitPlace(_ value: String) {
    guard let trimmed = normalizedPlaceName(value) else { return }
    selectedPlaceChip = trimmed
    placeText = ""
    store.suggestionRepository.upsert(fieldType: "場所", value: trimmed)
  }

  private func normalizedPersonName(_ value: String) -> String? {
    EpisodePersistence.normalizeNameInput(value, limit: EpisodePersistence.personNameCharacterLimit)
  }

  private func normalizedProjectName(_ value: String) -> String? {
    EpisodePersistence.normalizeNameInput(value, limit: EpisodePersistence.projectNameCharacterLimit)
  }

  private func normalizedPlaceName(_ value: String) -> String? {
    EpisodePersistence.normalizeNameInput(value, limit: EpisodePersistence.placeNameCharacterLimit)
  }

  private func applySuggestionSelection(fieldType: String, value: String) {
    switch fieldType {
    case "企画名":
      addProject(value)
    case "人物":
      addPerson(value)
    case "場所":
      commitPlace(value)
    default:
      break
    }
  }

  private func requestClose() {
    guard hasUnsavedDraftChanges else {
      router.hasUnsavedNewEpisodeChanges = false
      dismiss()
      return
    }
    pendingAction = .dismiss
    showsDiscardAlert = true
  }

  private func handlePendingRootTabSwitch(_ requestedTab: RootTab?) {
    guard let requestedTab else { return }
    guard hasUnsavedDraftChanges else {
      router.hasUnsavedNewEpisodeChanges = false
      router.commitRootTabSwitch(requestedTab)
      return
    }
    pendingAction = .switchRootTab(requestedTab)
    showsDiscardAlert = true
  }

  private func proceedPendingActionWithDiscard() {
    let action = pendingAction
    pendingAction = nil
    showsDiscardAlert = false
    router.hasUnsavedNewEpisodeChanges = false

    switch action {
    case .dismiss:
      dismiss()
    case .switchRootTab(let tab):
      router.commitRootTabSwitch(tab)
    case .none:
      break
    }
  }

  private func cancelPendingAction() {
    if case .switchRootTab(_) = pendingAction {
      router.cancelRootTabSwitchRequest()
    }
    pendingAction = nil
    showsDiscardAlert = false
  }

  private func syncUnsavedDraftStateToRouter() {
    router.hasUnsavedNewEpisodeChanges = hasUnsavedDraftChanges
  }

  private var discardAlertView: some View {
    ZStack {
      Color.black.opacity(0.25)
        .ignoresSafeArea()
        .onTapGesture {
          cancelPendingAction()
        }

      VStack(spacing: 20) {
        VStack(spacing: 12) {
          Text("入力内容を破棄しますか？")
            .font(NewEpisodeStyle.modalTitleFont)
            .foregroundColor(NewEpisodeStyle.headerText)
          Text("保存していない入力内容は失われます。")
            .font(NewEpisodeStyle.modalBodyFont)
            .foregroundColor(NewEpisodeStyle.labelText)
            .lineSpacing(4)
            .multilineTextAlignment(.center)
        }

        HStack(spacing: 12) {
          Button("破棄") {
            proceedPendingActionWithDiscard()
          }
          .font(NewEpisodeStyle.modalButtonFont)
          .foregroundColor(NewEpisodeStyle.modalDestructiveText)
          .frame(maxWidth: .infinity)
          .frame(height: NewEpisodeStyle.modalButtonHeight)
          .overlay(
            Capsule()
              .stroke(NewEpisodeStyle.modalButtonBorder, lineWidth: 1)
          )

          Button("編集を続ける") {
            cancelPendingAction()
          }
          .font(NewEpisodeStyle.modalButtonFont)
          .foregroundColor(Color.white)
          .frame(maxWidth: .infinity)
          .frame(height: NewEpisodeStyle.modalButtonHeight)
          .background(NewEpisodeStyle.modalPrimaryFill)
          .clipShape(Capsule())
        }
      }
      .padding(22)
      .background(NewEpisodeStyle.modalBackground)
      .clipShape(RoundedRectangle(cornerRadius: NewEpisodeStyle.modalCornerRadius, style: .continuous))
      .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
      .padding(.horizontal, 32)
    }
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
          requestClose()
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
    guard
      !trimmedTitle.isEmpty,
      !isBodyOverLimit,
      !isPersonNameOverLimit,
      !isProjectNameOverLimit,
      !isPlaceNameOverLimit
    else { return }
    let selectedPlaceValue = (selectedPlaceChip ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let placeValue =
      selectedPlaceValue.isEmpty ? normalizedPlaceName(placeText) : selectedPlaceValue
    _ = modelContext.createEpisode(
      title: trimmedTitle,
      body: trimmedBody.isEmpty ? nil : trimmedBody,
      date: selectedDate ?? Date(),
      unlockDate: selectedReleaseDate,
      type: nil,
      tags: selectedTags,
      persons: selectedPersons,
      projects: selectedProjects,
      emotions: selectedEmotions,
      place: placeValue
    )
    router.hasUnsavedNewEpisodeChanges = false
    dismiss()
  }
}

private enum NewEpisodeStyle {
  static let baseContentWidth: CGFloat = 360
  static let horizontalPadding: CGFloat = 21
  static let figmaTopInset: CGFloat = 61
  static let sectionSpacing: CGFloat = 16
  static let fieldSpacing: CGFloat = 8
  static let detailsSpacing: CGFloat = 30
  static let chipRowSpacing: CGFloat = 8
  static let chipSpacing: CGFloat = 8
  static let inputHeight: CGFloat = 41
  static let textAreaHeight: CGFloat = 200
  static let inputCornerRadius: CGFloat = 10
  static let inputBorderWidth: CGFloat = 0.66
  static let detailToggleHeight: CGFloat = 49
  static let detailToggleTopSpacing: CGFloat = 8
  static let detailToggleBorderWidth: CGFloat = 1
  static let detailBottomScrollPadding: CGFloat = 20
  static let chipHeightLarge: CGFloat = 36
  static let chipHeightSmall: CGFloat = 32
  static let tagGuideActionHeight: CGFloat = 32
  static let headerHeight: CGFloat = 56
  static let actionButtonHeight: CGFloat = 48
  static let actionButtonWidth: CGFloat = 120
  static let actionBarContentHeight: CGFloat = 72
  static let actionBarSeamOverlap: CGFloat = 2
  static let selectedChipHeight: CGFloat = 32
  static let calendarSheetHeight: CGFloat = 560
  static let calendarSheetSpacing: CGFloat = 10

  static let labelText = Color(hex: "4A5565")
  static let requiredText = Color(hex: "FB2C36")
  static let placeholderText = Color.black.opacity(0.5)
  static let inputText = HomeStyle.textInput
  static let inputBorder = Color(hex: "D1D5DC")
  static let chipFill = Color(hex: "F3F4F6")
  static let chipText = Color(hex: "364153")
  static let emotionPresetSelectedFill = HomeStyle.fabRed.opacity(0.12)
  static let emotionPresetSelectedBorder = HomeStyle.fabRed.opacity(0.5)
  static let emotionPresetSelectedText = HomeStyle.fabRed
  static let limitText = Color(hex: "9CA3AF")
  static let detailToggleFill = Color(hex: "F8FAFC")
  static let detailToggleBorder = Color(hex: "CBD3DF")
  static let headerText = HomeStyle.textPrimary
  static let modalBackground = Color.white
  static let modalPrimaryFill = HomeStyle.fabRed
  static let modalButtonBorder = Color(hex: "D1D5DC")
  static let modalDestructiveText = HomeStyle.destructiveRed

  static let primaryButtonFill = HomeStyle.fabRed
  static let primaryButtonText = Color.white
  static let secondaryButtonBorder = Color(hex: "CAC4D0")
  static let secondaryButtonText = Color(hex: "49454F")
  static let actionBarBackground = Color.white
  static let calendarTint = Color(hex: "355C7D")
  static let calendarToolbarButtonFill = Color(hex: "E2E8F0")
  static let calendarToolbarButtonText = Color(hex: "1F2937")
  static let calendarToolbarButtonDestructiveText = HomeStyle.destructiveRed

  static let labelFont = AppTypography.bodyEmphasis
  static let inputFont = AppTypography.body
  static let headerFont = AppTypography.formScreenTitle
  static let detailToggleFont = AppTypography.bodyEmphasis
  static let actionButtonFont = AppTypography.bodyEmphasis
  static let calendarToolbarButtonFont = AppTypography.subtextEmphasis
  static let modalTitleFont = AppTypography.sectionTitle
  static let modalBodyFont = AppTypography.body
  static let modalButtonFont = AppTypography.bodyEmphasis
  static let counterFont = AppTypography.subtext
  static let validationFont = AppTypography.subtext
  static let tagGuideFont = AppTypography.subtext
  static let validationText = HomeStyle.destructiveRed
  static let tagGuideText = Color(hex: "6B7280")
  static let modalCornerRadius: CGFloat = 16
  static let modalButtonHeight: CGFloat = 44

  static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateFormat = "yyyy/MM/dd"
    return formatter
  }()

  static let registeredTagSelectionSheetStyle = RegisteredTagSelectionSheetStyle(
    labelText: labelText,
    inputFont: inputFont,
    inputText: inputText,
    inputHeight: inputHeight,
    inputCornerRadius: inputCornerRadius,
    inputBorder: inputBorder,
    inputBorderWidth: inputBorderWidth,
    chipSpacing: chipSpacing,
    chipHeight: chipHeightSmall,
    chipFont: labelFont,
    chipText: chipText,
    chipFill: chipFill,
    closeButtonFont: calendarToolbarButtonFont
  )
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
  var onSubmit: (() -> Void)? = nil

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
        .onSubmit {
          onSubmit?()
          focused = false
          isFocused?.wrappedValue = false
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
  var allowsClearing: Bool = false

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
        VStack(spacing: NewEpisodeStyle.calendarSheetSpacing) {
          DatePicker("", selection: $tempDate, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(NewEpisodeStyle.calendarTint)
            .padding(.horizontal, 4)

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
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              showsPicker = false
            } label: {
              CalendarToolbarButtonLabel(
                title: "閉じる",
                font: NewEpisodeStyle.calendarToolbarButtonFont,
                fillColor: NewEpisodeStyle.calendarToolbarButtonFill,
                textColor: NewEpisodeStyle.calendarToolbarButtonText
              )
            }
            .buttonStyle(.plain)
          }
          if allowsClearing {
            ToolbarItem(placement: .topBarTrailing) {
              Button {
                date = nil
                showsPicker = false
              } label: {
                CalendarToolbarButtonLabel(
                  title: "クリア",
                  font: NewEpisodeStyle.calendarToolbarButtonFont,
                  fillColor: NewEpisodeStyle.calendarToolbarButtonFill,
                  textColor: NewEpisodeStyle.calendarToolbarButtonDestructiveText
                )
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      .presentationDetents([.height(NewEpisodeStyle.calendarSheetHeight)])
      .presentationDragIndicator(.visible)
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

private struct EmotionPresetChip: View {
  let title: String
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 6) {
      if isSelected {
        Image(systemName: "checkmark")
          .font(.system(size: 11, weight: .semibold))
      }
      Text(title)
        .font(NewEpisodeStyle.labelFont)
    }
      .foregroundColor(isSelected ? NewEpisodeStyle.emotionPresetSelectedText : NewEpisodeStyle.chipText)
      .padding(.horizontal, 14)
      .frame(height: NewEpisodeStyle.chipHeightSmall)
      .background(
        Capsule()
          .fill(isSelected ? NewEpisodeStyle.emotionPresetSelectedFill : NewEpisodeStyle.chipFill)
      )
      .overlay(
        Capsule()
          .stroke(
            isSelected ? NewEpisodeStyle.emotionPresetSelectedBorder : NewEpisodeStyle.inputBorder,
            lineWidth: isSelected ? 1.2 : 1
          )
      )
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
      .environmentObject(AppRouter())
  }
}

private enum NewEpisodePendingAction {
  case dismiss
  case switchRootTab(RootTab)
}

extension View {
  fileprivate func hideKeyboard() {
    #if canImport(UIKit)
      UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #endif
  }
}
