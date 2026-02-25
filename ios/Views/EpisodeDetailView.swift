import SwiftData
import SwiftUI

struct EpisodeDetailContainer: View {
  let episodeId: UUID
  @Query private var episodes: [Episode]

  init(episodeId: UUID) {
    self.episodeId = episodeId
    _episodes = Query(
      filter: #Predicate<Episode> { $0.id == episodeId && $0.isSoftDeleted == false })
  }

  var body: some View {
    if let episode = episodes.first {
      EpisodeDetailView(episode: episode)
    } else {
      EmptyView()
    }
  }
}

struct EpisodeDetailView: View {
  @EnvironmentObject private var store: EpisodeStore
  @EnvironmentObject private var router: AppRouter
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  let episode: Episode
  @Query(
    filter: #Predicate<Tag> { $0.isSoftDeleted == false },
    sort: [SortDescriptor(\Tag.nameNormalized)]
  )
  private var allTags: [Tag]
  @State private var selectedTab: EpisodeDetailTab = .registration
  @State private var showsDetails = true
  @State private var isEditing = false
  @State private var titleText: String
  @State private var bodyText: String
  @State private var dateValue: Date
  @State private var releaseDateValue: Date?
  @State private var didCopyBody = false
  @State private var didCopyTitle = false
  @State private var showsDiscardAlert = false
  @State private var editBaseline = DetailEditBaseline()
  @State private var pendingAction: PendingAction?
  @State private var showsReleaseLogSheet = false
  @State private var editingHistoryId: UUID?
  @State private var logDraft = ReleaseLogDraft()
  @State private var personText = ""
  @State private var selectedPersons: [String] = []
  @State private var tagText = ""
  @State private var selectedTags: [String] = []
  @State private var projectText = ""
  @State private var selectedProjects: [String] = []
  @State private var selectedEmotions: [String] = []
  @State private var placeText = ""
  @State private var selectedPlace: String?

  // focus states for inputs to control inline suggestion visibility
  @State private var personFieldFocused = false
  @State private var projectFieldFocused = false
  @State private var placeFieldFocused = false

  // sheet is presented via `suggestionManagerField` using `.sheet(item:)` to avoid presentation races
  private struct SuggestionField: Identifiable {
    let id = UUID()
    let field: String
  }

  @State private var suggestionManagerField: SuggestionField? = nil
  @State private var showsTagSelectionSheet = false

  private let maxPersons = 10
  private let maxTags = 10
  private let maxEmotions = 3
  private let maxProjects = 3

  init(episode: Episode) {
    self.episode = episode
    _titleText = State(initialValue: episode.title)
    _bodyText = State(initialValue: episode.body ?? "")
    _dateValue = State(initialValue: episode.date)
    _releaseDateValue = State(initialValue: episode.unlockDate)
    _selectedTags = State(initialValue: EpisodeDetailView.orderedTagChips(from: episode.tags))
  }

  var body: some View {
    GeometryReader { proxy in
      let contentWidth = min(
        DetailStyle.baseContentWidth, proxy.size.width - DetailStyle.horizontalPadding * 2)
      let horizontalPadding = max(
        DetailStyle.horizontalPadding, (proxy.size.width - contentWidth) / 2)
      let topPadding = max(0, DetailStyle.figmaTopInset - proxy.safeAreaInsets.top)
      let tabBarOffset = max(0, HomeStyle.tabBarHeight - 48)

      ZStack {
        VStack(spacing: 0) {
          VStack(alignment: .leading, spacing: DetailStyle.sectionSpacing) {
            headerView
            tabBarView
          }
          .padding(.top, topPadding)
          .padding(.horizontal, horizontalPadding)
          .background(Color.white)

          ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: DetailStyle.sectionSpacing) {
              if selectedTab == .registration {
                registrationInfoView
              } else {
                releaseLogPlaceholder
              }
            }
            .padding(.top, DetailStyle.sectionSpacing)
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 24 + tabBarOffset)
            .frame(maxWidth: .infinity, alignment: .topLeading)
          }
          .contentShape(Rectangle())
          .onTapGesture {
            hideKeyboard()
          }
        }
        .background(Color.white)

        if showsDiscardAlert {
          discardAlertView
        }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $showsReleaseLogSheet) {
      ReleaseLogSheet(
        draft: $logDraft,
        isEditing: editingHistoryId != nil,
        onSave: saveReleaseLog,
        onDelete: deleteReleaseLog,
        onCancel: { showsReleaseLogSheet = false }
      )
      .presentationDetents([.height(640)])
      .presentationDragIndicator(.visible)
    }
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
        style: DetailStyle.registeredTagSelectionSheetStyle
      )
      .presentationDetents([.medium, .large])
      .presentationDragIndicator(.visible)
      .presentationBackground(Color.white)
    }
    .onChange(of: tagText) { _, newValue in
      let normalized = EpisodePersistence.normalizeTagInputWhileEditing(newValue)
      if normalized != newValue {
        tagText = normalized
      }
    }
    .onChange(of: isEditing) { _, _ in
      syncUnsavedEditStateToRouter()
    }
    .onChange(of: hasUnsavedChanges) { _, _ in
      syncUnsavedEditStateToRouter()
    }
    .onChange(of: router.pendingRootTabSwitch) { _, requestedTab in
      handlePendingRootTabSwitch(requestedTab)
    }
    .onAppear {
      syncUnsavedEditStateToRouter()
    }
    .onDisappear {
      router.hasUnsavedEpisodeDetailChanges = false
    }
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

  private var personValidationMessage: String? {
    guard isPersonNameOverLimit else { return nil }
    return "人物は\(EpisodePersistence.personNameCharacterLimit)文字以内で入力してください"
  }

  private var projectValidationMessage: String? {
    guard isProjectNameOverLimit else { return nil }
    return "企画名は\(EpisodePersistence.projectNameCharacterLimit)文字以内で入力してください"
  }

  private var placeValidationMessage: String? {
    guard isPlaceNameOverLimit else { return nil }
    return "場所は\(EpisodePersistence.placeNameCharacterLimit)文字以内で入力してください"
  }

  private var isRegistrationSaveEnabled: Bool {
    !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !isBodyOverLimit
      && !isPersonNameOverLimit
      && !isProjectNameOverLimit
      && !isPlaceNameOverLimit
  }

  private var headerView: some View {
    HStack(spacing: 8) {
      Button {
        handleBack()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(DetailStyle.headerText)
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
          .padding(8)
      }
      .buttonStyle(.plain)

      Text("エピソード詳細")
        .font(DetailStyle.headerFont)
        .foregroundColor(DetailStyle.headerText)

      Spacer()

      if selectedTab == .registration {
        Button {
          toggleEdit()
        } label: {
          HStack(spacing: 4) {
            Image(systemName: isEditing ? "checkmark" : "pencil")
              .font(.system(size: 16, weight: .semibold))
              .frame(width: 24, height: 24)
            Text(isEditing ? "保存" : "編集")
              .font(DetailStyle.editButtonFont)
          }
          .foregroundColor(DetailStyle.editAccent)
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(
            Capsule()
              .fill(DetailStyle.editButtonFill)
          )
          .overlay(
            Capsule()
              .stroke(DetailStyle.editButtonBorder, lineWidth: 1)
          )
        }
        .buttonStyle(.plain)
        .disabled(isEditing && !isRegistrationSaveEnabled)
        .opacity(isEditing && !isRegistrationSaveEnabled ? 0.6 : 1)
      }
    }
    .frame(height: DetailStyle.headerHeight)
  }

  private var tabBarView: some View {
    HStack(spacing: 0) {
      DetailTabButton(
        title: "登録情報",
        isSelected: selectedTab == .registration,
        action: { requestTabSwitch(.registration) }
      )
      DetailTabButton(
        title: "解禁ログ",
        isSelected: selectedTab == .releaseLog,
        badgeCount: releaseLogCount,
        action: { requestTabSwitch(.releaseLog) }
      )
    }
    .frame(height: DetailStyle.tabBarHeight)
    .overlay(
      Rectangle()
        .fill(DetailStyle.tabBarBorder)
        .frame(height: DetailStyle.tabBarBorderWidth),
      alignment: .bottom
    )
  }

  private var registrationInfoView: some View {
    VStack(alignment: .leading, spacing: DetailStyle.sectionSpacing) {
      DetailStatusBadge(isUnlocked: episode.isUnlocked)

      VStack(alignment: .leading, spacing: DetailStyle.fieldGroupSpacing) {
        VStack(alignment: .leading, spacing: DetailStyle.fieldSpacing) {
          HStack {
            DetailFieldLabel(title: "タイトル", required: true)
            Spacer()
            if didCopyTitle {
              Text("コピー済み")
                .font(DetailStyle.copyLabelFont)
                .foregroundColor(DetailStyle.copyAccent)
            }
            Button(action: copyTitle) {
              Image(systemName: didCopyTitle ? "checkmark.circle.fill" : "doc.on.doc")
                .font(.system(size: DetailStyle.copyIconSize, weight: .semibold))
                .foregroundColor(didCopyTitle ? DetailStyle.copyAccent : DetailStyle.chipText)
                .frame(width: DetailStyle.copyButtonSize, height: DetailStyle.copyButtonSize)
            }
            .buttonStyle(.plain)
          }
          if isEditing {
            EditableField(placeholder: "タイトルを入力", text: $titleText)
          } else {
            ReadOnlyField(text: titleText)
          }
        }

        HStack(spacing: DetailStyle.columnSpacing) {
          VStack(alignment: .leading, spacing: DetailStyle.fieldSpacing) {
            DetailFieldLabel(title: "日付", required: true)
            if isEditing {
              DetailDateField(date: $dateValue)
            } else {
              ReadOnlyField(text: DetailStyle.dateFormatter.string(from: dateValue))
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          VStack(alignment: .leading, spacing: DetailStyle.fieldSpacing) {
            DetailFieldLabel(title: "解禁可能日")
            if isEditing {
              DetailOptionalDateField(title: "解禁可能日", date: $releaseDateValue, placeholder: "未設定")
            } else {
              ReadOnlyField(
                text: releaseDateValue.map { DetailStyle.dateFormatter.string(from: $0) } ?? "未設定")
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        VStack(alignment: .leading, spacing: DetailStyle.fieldSpacing) {
          HStack {
            DetailFieldLabel(title: "本文")
            if isEditing {
              Text(bodyCharacterCountText)
                .font(DetailStyle.counterFont)
                .foregroundColor(DetailStyle.counterText)
            }
            Spacer()
            if didCopyBody {
              Text("コピー済み")
                .font(DetailStyle.copyLabelFont)
                .foregroundColor(DetailStyle.copyAccent)
            }
            Button(action: copyBody) {
              Image(systemName: didCopyBody ? "checkmark.circle.fill" : "doc.on.doc")
                .font(.system(size: DetailStyle.copyIconSize, weight: .semibold))
                .foregroundColor(didCopyBody ? DetailStyle.copyAccent : DetailStyle.chipText)
                .frame(width: DetailStyle.copyButtonSize, height: DetailStyle.copyButtonSize)
            }
            .buttonStyle(.plain)
          }
          if isEditing {
            EditableTextArea(
              placeholder: "本文を入力",
              text: $bodyText
            )
          } else {
            ReadOnlyTextArea(text: bodyText.isEmpty ? "本文なし" : bodyText)
          }
          if let bodyLengthValidationMessage, isEditing {
            Text(bodyLengthValidationMessage)
              .font(DetailStyle.validationFont)
              .foregroundColor(DetailStyle.validationText)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }

      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          showsDetails.toggle()
        }
      } label: {
        HStack(spacing: 8) {
          Text(showsDetails ? "詳細を閉じる" : "詳細を開く")
            .font(DetailStyle.detailToggleFont)
            .foregroundColor(DetailStyle.detailToggleText)
          Image(systemName: showsDetails ? "chevron.up" : "chevron.down")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(DetailStyle.detailToggleText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: DetailStyle.detailToggleHeight)
        .overlay(
          RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
            .stroke(DetailStyle.inputBorder, lineWidth: DetailStyle.inputBorderWidth)
        )
      }
      .buttonStyle(.plain)

      if showsDetails {
        detailSections
      }
    }
  }

  private var detailSections: some View {
    VStack(alignment: .leading, spacing: DetailStyle.detailsSpacing) {
      detailSection(
        title: "企画名",
        existing: displayProjects,
        showsEditorWhenEditing: true,
        editor: {
          multiChipEditor(
            placeholder: "企画名を入力してEnter",
            text: $projectText,
            selections: $selectedProjects,
            maxSelections: maxProjects,
            suggestions: [],
            fieldType: "企画名",
            validationMessage: projectValidationMessage,
            onCommit: addProject,
            onRemove: removeProject
          )
        }
      )

      detailSection(
        title: "タグ",
        existing: displayTagChips,
        showsEditorWhenEditing: true,
        editor: {
          multiChipEditor(
            placeholder: "タグを入力してEnter",
            text: $tagText,
            selections: $selectedTags,
            maxSelections: maxTags,
            suggestions: registeredTagSuggestions,
            fieldType: "",
            validationMessage: tagValidationMessage,
            onCommit: addTag,
            onRemove: removeTag
          )
        }
      )

      detailSection(
        title: "感情",
        existing: displayEmotions,
        showsEditorWhenEditing: true,
        editor: {
          emotionPresetEditor
        }
      )

      detailSection(
        title: "人物",
        existing: displayPersons,
        showsEditorWhenEditing: true,
        editor: {
          multiChipEditor(
            placeholder: "人物名を入力してEnter",
            text: $personText,
            selections: $selectedPersons,
            maxSelections: maxPersons,
            suggestions: [],
            fieldType: "人物",
            validationMessage: personValidationMessage,
            onCommit: addPerson,
            onRemove: removePerson
          )
        }
      )

      detailSection(
        title: "場所",
        existing: displayPlaces,
        showsEditorWhenEditing: true,
        editor: {
          VStack(alignment: .leading, spacing: DetailStyle.fieldSpacing) {
            DetailChipInputField(
              placeholder: "場所を入力",
              text: $placeText,
              selection: $selectedPlace,
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
            .onReceive(NotificationCenter.default.publisher(for: .openSuggestionManagerSheet)) {
              note in
              if let field = note.object as? String, field == "場所" {
                suggestionManagerField = SuggestionField(field: field)
              }
            }
            if let placeValidationMessage {
              Text(placeValidationMessage)
                .font(DetailStyle.validationFont)
                .foregroundColor(DetailStyle.validationText)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      )
    }
  }

  private var emotionPresetEditor: some View {
    FlowLayout(spacing: DetailStyle.chipSpacing) {
      ForEach(emotionChipOptions, id: \.self) { option in
        let selected = selectedEmotions.contains(option)
        let disabled = !selected && selectedEmotions.count >= maxEmotions
        Button {
          toggleEmotion(option)
        } label: {
          EmotionPresetDetailChip(title: option, isSelected: selected)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
      }
    }
  }

  private var releaseLogPlaceholder: some View {
    releaseLogView
  }

  private var releaseLogView: some View {
    VStack(alignment: .leading, spacing: DetailStyle.releaseLogSpacing) {
      Button {
        openNewReleaseLog()
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "plus")
            .font(.system(size: 16, weight: .bold))
          Text("記録を追加")
            .font(DetailStyle.releaseLogButtonFont)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: DetailStyle.releaseLogButtonHeight)
        .background(DetailStyle.releaseLogButtonFill)
        .clipShape(RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius))
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: DetailStyle.releaseLogCardSpacing) {
        ForEach(releaseLogEntries) { entry in
          ReleaseLogCard(entry: entry) {
            openEditReleaseLog(entry)
          }
        }
      }
    }
  }

  private var episodeTagNames: [String] {
    EpisodeDetailView.orderedTagChips(from: episode.tags)
  }

  private var displayTagChips: [String] {
    selectedTags.isEmpty ? episodeTagNames : selectedTags
  }

  private var displayPersons: [String] {
    isEditing ? selectedPersons : episode.persons.map(\.name)
  }

  private var displayProjects: [String] {
    isEditing ? selectedProjects : episode.projects.map(\.name)
  }

  private var displayEmotions: [String] {
    isEditing ? selectedEmotions : episode.emotions.map(\.name)
  }

  private var displayPlaces: [String] {
    if isEditing {
      return selectedPlace.map { [$0] } ?? []
    }
    return episode.places.map(\.name)
  }

  private var registeredTagSuggestions: [String] {
    allTags.sorted { $0.updatedAt > $1.updatedAt }.compactMap(displayTagName)
  }

  private var releaseLogCount: Int {
    releaseLogEntries.count
  }

  private var releaseLogEntries: [ReleaseLogEntry] {
    let logs = episode.unlockLogs.filter { !$0.isSoftDeleted }
    guard !logs.isEmpty else { return [] }
    return logs.sorted { $0.talkedAt > $1.talkedAt }.map { log in
      let outcome = ReleaseLogOutcome(rawValue: log.reaction)
      let chips: [ReleaseLogChip] =
        outcome.map { [ReleaseLogChip(label: $0.label, style: $0.chipStyle)] } ?? []

      return ReleaseLogEntry(
        id: log.id,
        date: log.talkedAt,
        mediaReleaseDate: log.mediaPublicAt,
        projectName: log.projectNameText ?? "",
        outcome: outcome,
        chips: chips,
        note: log.memo
      )
    }
  }

  private func fallbackChips(from values: [String]) -> [String] {
    values.isEmpty ? ["未設定"] : values
  }

  private func copyBody() {
    #if canImport(UIKit)
      guard !bodyText.isEmpty else { return }
      UIPasteboard.general.string = bodyText
      indicateCopy($didCopyBody)
    #endif
  }

  private func copyTitle() {
    #if canImport(UIKit)
      guard !titleText.isEmpty else { return }
      UIPasteboard.general.string = titleText
      indicateCopy($didCopyTitle)
    #endif
  }

  private func indicateCopy(_ flag: Binding<Bool>) {
    withAnimation(.easeInOut(duration: 0.2)) {
      flag.wrappedValue = true
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
      withAnimation(.easeInOut(duration: 0.2)) {
        flag.wrappedValue = false
      }
    }
  }

  private func toggleEdit() {
    if isEditing {
      if saveChanges() {
        isEditing = false
      }
    } else {
      selectedPersons = episode.persons.map(\.name)
      selectedTags = EpisodeDetailView.orderedTagChips(from: episode.tags)
      selectedProjects = episode.projects.map(\.name)
      selectedEmotions = episode.emotions.map(\.name)
      selectedPlace = episode.places.first?.name
      editBaseline = currentSnapshot()
      isEditing = true
    }
  }

  private func saveChanges() -> Bool {
    let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
    let selectedPlaceValue = (selectedPlace ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let placeValue = selectedPlaceValue.isEmpty ? normalizedPlaceName(placeText) : selectedPlaceValue
    guard
      !trimmedTitle.isEmpty,
      !isBodyOverLimit,
      !isPersonNameOverLimit,
      !isProjectNameOverLimit,
      !isPlaceNameOverLimit
    else { return false }

    modelContext.updateEpisode(
      episode,
      title: trimmedTitle,
      body: trimmedBody.isEmpty ? nil : trimmedBody,
      date: dateValue,
      unlockDate: releaseDateValue,
      type: episode.type,
      tags: selectedTags,
      persons: selectedPersons,
      projects: selectedProjects,
      emotions: selectedEmotions,
      place: placeValue
    )
    return true
  }

  private var hasUnsavedChanges: Bool {
    currentSnapshot() != editBaseline
  }

  private func currentSnapshot() -> DetailEditBaseline {
    DetailEditBaseline(
      title: titleText,
      body: bodyText,
      date: dateValue,
      releaseDate: releaseDateValue,
      persons: selectedPersons,
      personText: personText,
      tags: selectedTags,
      tagText: tagText,
      projects: selectedProjects,
      projectText: projectText,
      emotions: selectedEmotions,
      place: selectedPlace,
      placeText: placeText
    )
  }

  private func handleBack() {
    if isEditing && hasUnsavedChanges {
      pendingAction = .back
      showsDiscardAlert = true
    } else {
      dismiss()
    }
  }

  private func requestTabSwitch(_ tab: EpisodeDetailTab) {
    guard tab != selectedTab else { return }
    if isEditing && hasUnsavedChanges {
      pendingAction = .switchTab(tab)
      showsDiscardAlert = true
    } else {
      isEditing = false
      selectedTab = tab
      hideKeyboard()
    }
  }

  private func discardChanges() {
    applySnapshot(editBaseline)
    isEditing = false
  }

  private func applySnapshot(_ snapshot: DetailEditBaseline) {
    titleText = snapshot.title
    bodyText = snapshot.body
    dateValue = snapshot.date
    releaseDateValue = snapshot.releaseDate
    selectedPersons = snapshot.persons
    personText = snapshot.personText
    selectedTags = snapshot.tags
    tagText = snapshot.tagText
    selectedProjects = snapshot.projects
    projectText = snapshot.projectText
    selectedEmotions = snapshot.emotions
    selectedPlace = snapshot.place
    placeText = snapshot.placeText
  }

  private var discardAlertView: some View {
    ZStack {
      Color.black.opacity(0.25)
        .ignoresSafeArea()
        .onTapGesture {
          cancelDiscardPrompt()
        }

      VStack(spacing: 20) {
        VStack(spacing: 12) {
          Text("変更を保存しますか？")
            .font(DetailStyle.modalTitleFont)
            .foregroundColor(DetailStyle.headerText)
          Text("保存せずに戻ると変更内容は失われます。")
            .font(DetailStyle.modalBodyFont)
            .foregroundColor(DetailStyle.labelText)
            .lineSpacing(4)
            .multilineTextAlignment(.center)
        }

        HStack(spacing: 12) {
          Button("破棄") {
            discardChanges()
            proceedAfterPrompt()
          }
          .font(DetailStyle.modalButtonFont)
          .foregroundColor(DetailStyle.modalDestructiveText)
          .frame(maxWidth: .infinity)
          .frame(height: DetailStyle.modalButtonHeight)
          .overlay(
            Capsule()
              .stroke(DetailStyle.modalButtonBorder, lineWidth: 1)
          )

          Button("保存") {
            if saveChanges() {
              isEditing = false
              editBaseline = currentSnapshot()
              proceedAfterPrompt()
            }
          }
          .font(DetailStyle.modalButtonFont)
          .foregroundColor(Color.white)
          .frame(maxWidth: .infinity)
          .frame(height: DetailStyle.modalButtonHeight)
          .background(DetailStyle.modalPrimaryFill)
          .clipShape(Capsule())
          .disabled(!isRegistrationSaveEnabled)
          .opacity(isRegistrationSaveEnabled ? 1 : 0.6)
        }

        Button("キャンセル") {
          cancelDiscardPrompt()
        }
        .font(DetailStyle.modalButtonFont)
        .foregroundColor(DetailStyle.labelText)
      }
      .padding(22)
      .background(DetailStyle.modalBackground)
      .clipShape(RoundedRectangle(cornerRadius: DetailStyle.modalCornerRadius, style: .continuous))
      .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
      .padding(.horizontal, 32)
    }
  }

  private func proceedAfterPrompt() {
    showsDiscardAlert = false
    switch pendingAction {
    case .back:
      dismiss()
    case .switchTab(let tab):
      selectedTab = tab
    case .switchRootTab(let tab):
      router.commitRootTabSwitch(tab)
    case .none:
      break
    }
    pendingAction = nil
    hideKeyboard()
  }

  private func openNewReleaseLog() {
    logDraft = ReleaseLogDraft(talkedAt: Date())
    editingHistoryId = nil
    showsReleaseLogSheet = true
  }

  private func openEditReleaseLog(_ entry: ReleaseLogEntry) {
    logDraft = ReleaseLogDraft(
      talkedAt: entry.date,
      mediaReleaseDate: entry.mediaReleaseDate,
      projectName: entry.projectName,
      outcome: entry.outcome,
      memo: entry.note
    )
    editingHistoryId = entry.id
    showsReleaseLogSheet = true
  }

  private func saveReleaseLog() {
    let trimmedProject = logDraft.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedMemo = logDraft.memo.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedProject.isEmpty else { return }
    guard let outcome = logDraft.outcome else { return }

    if let historyId = editingHistoryId {
      if let log = episode.unlockLogs.first(where: { $0.id == historyId }) {
        modelContext.updateUnlockLog(
          log,
          talkedAt: logDraft.talkedAt,
          mediaPublicAt: logDraft.mediaReleaseDate,
          projectNameText: trimmedProject,
          reaction: outcome.rawValue,
          memo: trimmedMemo
        )
      }
    } else {
      modelContext.createUnlockLog(
        episode: episode,
        talkedAt: logDraft.talkedAt,
        mediaPublicAt: logDraft.mediaReleaseDate,
        projectNameText: trimmedProject,
        reaction: outcome.rawValue,
        memo: trimmedMemo
      )
    }

    showsReleaseLogSheet = false
    editingHistoryId = nil
  }

  private func deleteReleaseLog() {
    guard let historyId = editingHistoryId else { return }
    if let log = episode.unlockLogs.first(where: { $0.id == historyId }) {
      modelContext.softDeleteUnlockLog(log)
    }
    showsReleaseLogSheet = false
    editingHistoryId = nil
  }

  private func detailSection<Editor: View>(
    title: String,
    existing: [String],
    showsEditorWhenEditing: Bool,
    @ViewBuilder editor: @escaping () -> Editor
  ) -> some View {
    VStack(alignment: .leading, spacing: DetailStyle.fieldSpacing) {
      DetailFieldLabel(title: title)
      if isEditing && showsEditorWhenEditing {
        editor()
      } else {
        DetailChipWrap(chips: fallbackChips(from: existing))
      }
    }
  }

  private func multiChipEditor(
    placeholder: String,
    text: Binding<String>,
    selections: Binding<[String]>,
    maxSelections: Int,
    suggestions: [String],
    fieldType: String,
    validationMessage: String? = nil,
    onCommit: @escaping (String) -> Void,
    onRemove: @escaping (String) -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: DetailStyle.fieldSpacing) {
      DetailMultiChipInputField(
        placeholder: placeholder,
        text: text,
        selections: selections,
        maxSelections: maxSelections,
        onCommit: { onCommit(text.wrappedValue) },
        onRemove: onRemove,
        isFocused: bindingForFieldType(fieldType)
      )

      if let validationMessage {
        Text(validationMessage)
          .font(DetailStyle.validationFont)
          .foregroundColor(DetailStyle.validationText)
          .fixedSize(horizontal: false, vertical: true)
      }

      if fieldType.isEmpty {
        Text(TagInputConstants.guideText)
          .font(DetailStyle.tagGuideFont)
          .foregroundColor(DetailStyle.tagGuideText)
          .fixedSize(horizontal: false, vertical: true)
      }

      let trimmed = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
      if fieldType.isEmpty {
        let filtered = TagInputHelpers.filteredSuggestions(
          query: trimmed,
          selectedTags: selectedTags,
          registeredTagSuggestions: suggestions
        )
        HStack(spacing: 8) {
          Button {
            showsTagSelectionSheet = true
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "tag")
                .font(.system(size: 12, weight: .semibold))
              Text("登録タグ選択")
            }
            .font(DetailStyle.tagGuideFont)
            .foregroundColor(HomeStyle.fabRed)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(HomeStyle.fabRed.opacity(0.08))
            .overlay(
              Capsule()
                .stroke(HomeStyle.fabRed.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DetailStyle.chipSpacing) {
              ForEach(filtered, id: \.self) { title in
                Button {
                  onCommit(title)
                } label: {
                  DetailChip(title: title)
                }
                .buttonStyle(.plain)
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      } else {
        // history-backed fields: show history for empty input, and filtered suggestions for typed input
        InlineSuggestionList(
          fieldType: fieldType, query: text, maxItems: 3, isActive: isFieldActive(fieldType),
          onSelect: onCommit
        )
        .environmentObject(store)
        .onReceive(NotificationCenter.default.publisher(for: .openSuggestionManagerSheet)) { note in
          if let field = note.object as? String, field == fieldType {
            suggestionManagerField = SuggestionField(field: field)
          }
        }
      }
    }
  }

  private func handlePendingRootTabSwitch(_ requestedTab: RootTab?) {
    guard let requestedTab else { return }
    guard isEditing && hasUnsavedChanges else {
      router.commitRootTabSwitch(requestedTab)
      return
    }
    pendingAction = .switchRootTab(requestedTab)
    showsDiscardAlert = true
  }

  private func cancelDiscardPrompt() {
    if case .switchRootTab(_) = pendingAction {
      router.cancelRootTabSwitchRequest()
    }
    showsDiscardAlert = false
    pendingAction = nil
  }

  private func bindingForFieldType(_ fieldType: String) -> Binding<Bool>? {
    switch fieldType {
    case "人物": return $personFieldFocused
    case "企画名": return $projectFieldFocused
    case "場所": return $placeFieldFocused
    default: return nil
    }
  }

  private func isFieldActive(_ fieldType: String) -> Bool {
    switch fieldType {
    case "人物": return personFieldFocused
    case "企画名": return projectFieldFocused
    case "場所": return placeFieldFocused
    default: return false
    }
  }

  private func suggestionRow(_ titles: [String], onSelect: @escaping (String) -> Void) -> some View
  {
    FlowLayout(spacing: DetailStyle.chipSpacing) {
      ForEach(titles, id: \.self) { title in
        Button {
          onSelect(title)
        } label: {
          DetailChip(title: title)
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func addPerson(_ name: String) {
    guard let normalized = normalizedPersonName(name) else { return }
    addTo(&selectedPersons, value: normalized, max: maxPersons, clear: { personText = "" })
    store.suggestionRepository.upsert(fieldType: "人物", value: normalized)
  }

  private func removePerson(_ name: String) {
    selectedPersons.removeAll { $0 == name }
  }

  private func addTag(_ value: String) {
    guard let normalized = normalizedTag(value) else { return }
    addTo(&selectedTags, value: normalized, max: maxTags, clear: { tagText = "" })
    // Tags are managed separately; do not record as suggestion here
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

  private func displayTagName(_ tag: Tag) -> String? {
    guard let normalized = EpisodePersistence.normalizeTagName(tag.name)?.name else {
      return nil
    }
    return "#\(normalized)"
  }

  private static func orderedTagChips(from tags: [Tag]) -> [String] {
    tags
      .sorted { $0.updatedAt < $1.updatedAt }
      .compactMap { tag in
        guard let normalized = EpisodePersistence.normalizeTagName(tag.name)?.name else {
          return nil
        }
        return "#\(normalized)"
      }
  }

  private var tagValidationMessage: String? {
    TagInputHelpers.validationMessage(for: tagText)
  }

  private func addProject(_ value: String) {
    guard let normalized = normalizedProjectName(value) else { return }
    addTo(&selectedProjects, value: normalized, max: maxProjects, clear: { projectText = "" })
    store.suggestionRepository.upsert(fieldType: "企画名", value: normalized)
  }

  private func removeProject(_ value: String) {
    selectedProjects.removeAll { $0 == value }
  }

  private func addEmotion(_ value: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard EpisodePersistence.emotionPresetOptions.contains(trimmed) else { return }
    addTo(&selectedEmotions, value: trimmed, max: maxEmotions, clear: {})
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
    guard let normalized = normalizedPlaceName(value) else { return }
    selectedPlace = normalized
    placeText = ""
    store.suggestionRepository.upsert(fieldType: "場所", value: normalized)
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

  private func syncUnsavedEditStateToRouter() {
    router.hasUnsavedEpisodeDetailChanges = isEditing && hasUnsavedChanges
  }

  private func addTo(_ collection: inout [String], value: String, max: Int, clear: () -> Void) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard collection.count < max else {
      clear()
      return
    }
    if !collection.contains(trimmed) {
      collection.append(trimmed)
    }
    clear()
  }
}

struct EpisodeDetailView_Previews: PreviewProvider {
  static var previews: some View {
    let sample = Episode(
      date: Date(),
      title: "サンプルエピソード",
      body: "本文のサンプル"
    )
    NavigationStack {
      EpisodeDetailView(episode: sample)
        .environmentObject(EpisodeStore())
        .environmentObject(AppRouter())
    }
  }
}

private enum EpisodeDetailTab {
  case registration
  case releaseLog
}

private enum PendingAction {
  case back
  case switchTab(EpisodeDetailTab)
  case switchRootTab(RootTab)
}

private struct DetailEditBaseline: Equatable {
  var title: String = ""
  var body: String = ""
  var date: Date = .init()
  var releaseDate: Date? = nil
  var persons: [String] = []
  var personText: String = ""
  var tags: [String] = []
  var tagText: String = ""
  var projects: [String] = []
  var projectText: String = ""
  var emotions: [String] = []
  var place: String? = nil
  var placeText: String = ""
}

private enum DetailStyle {
  static let baseContentWidth: CGFloat = 374
  static let horizontalPadding: CGFloat = 14
  static let figmaTopInset: CGFloat = 61
  static let sectionSpacing: CGFloat = 20
  static let fieldGroupSpacing: CGFloat = 16
  static let fieldSpacing: CGFloat = 8
  static let columnSpacing: CGFloat = 12
  static let inputHeight: CGFloat = 41
  static let textAreaHeight: CGFloat = 169
  static let inputCornerRadius: CGFloat = 10
  static let inputBorderWidth: CGFloat = 0.66
  static let detailToggleHeight: CGFloat = 52
  static let headerHeight: CGFloat = 48
  static let tabBarHeight: CGFloat = 48
  static let tabBarBorderWidth: CGFloat = 0.66
  static let tabIndicatorHeight: CGFloat = 2
  static let chipHeight: CGFloat = 28
  static let detailsSpacing: CGFloat = 24
  static let chipSpacing: CGFloat = 8
  static let iconButtonSize: CGFloat = 24
  static let calendarSheetHeight: CGFloat = 560
  static let calendarSheetSpacing: CGFloat = 10

  static let labelText = Color(hex: "4A5565")
  static let requiredText = Color(hex: "FB2C36")
  static let inputText = Color(hex: "0A0A0A")
  static let inputBorder = Color(hex: "D1D5DC")
  static let chipFill = Color(hex: "F3F4F6")
  static let chipText = Color(hex: "364153")
  static let emotionPresetSelectedFill = HomeStyle.fabRed.opacity(0.12)
  static let emotionPresetSelectedBorder = HomeStyle.fabRed.opacity(0.5)
  static let emotionPresetSelectedText = HomeStyle.fabRed
  static let headerText = Color(hex: "2A2525")
  static let tabSelectedText = Color(hex: "2A2525")
  static let tabUnselectedText = Color(hex: "4A5565")
  static let tabBarBorder = Color(hex: "D1D5DC")
  static let tabIndicatorFill = HomeStyle.fabRed
  static let detailToggleText = Color(hex: "364153")
  static let readOnlyFill = Color(hex: "F3F4F6")
  static let readOnlyBorder = Color(hex: "E5E7EB")
  static let editAccent = HomeStyle.fabRed
  static let editButtonFill = HomeStyle.fabRed.opacity(0.12)
  static let editButtonBorder = HomeStyle.fabRed.opacity(0.45)
  static let copyAccent = HomeStyle.fabRed
  static let modalBackground = Color.white
  static let modalPrimaryFill = HomeStyle.fabRed
  static let modalButtonBorder = Color(hex: "D1D5DC")
  static let modalDestructiveText = HomeStyle.destructiveRed
  static let modalDestructiveFill = HomeStyle.destructiveRed
  static let releaseLogButtonFill = Color(hex: "6E0E0C")
  static let releaseLogNoteColor = Color(hex: "364153")
  static let releaseLogOutcomeFill = Color(hex: "F3F4F6")
  static let releaseLogOutcomeSelectedFill = HomeStyle.fabRed
  static let validationText = HomeStyle.destructiveRed
  static let tagGuideText = Color(hex: "6B7280")
  static let counterText = Color(hex: "9CA3AF")
  static let calendarTint = Color(hex: "355C7D")
  static let calendarToolbarButtonFill = Color(hex: "E2E8F0")
  static let calendarToolbarButtonText = Color(hex: "1F2937")
  static let calendarToolbarButtonDestructiveText = HomeStyle.destructiveRed

  static let labelFont = Font.system(size: 14, weight: .medium)
  static let inputFont = Font.system(size: 16, weight: .regular)
  static let headerFont = AppTypography.formScreenTitle
  static let tabSelectedFont = Font.system(size: 16, weight: .semibold)
  static let tabFont = Font.system(size: 16, weight: .semibold)
  static let detailToggleFont = Font.system(size: 16, weight: .medium)
  static let badgeFont = Font.system(size: 14, weight: .medium)
  static let chipFont = Font.system(size: 14, weight: .medium)
  static let counterFont = Font.system(size: 12, weight: .regular)
  static let validationFont = Font.system(size: 12, weight: .regular)
  static let tagGuideFont = Font.system(size: 12, weight: .regular)
  static let copyLabelFont = Font.system(size: 12, weight: .medium)
  static let editButtonFont = Font.system(size: 15, weight: .semibold)
  static let modalTitleFont = Font.system(size: 17, weight: .semibold)
  static let modalBodyFont = Font.system(size: 14, weight: .regular)
  static let modalButtonFont = Font.system(size: 16, weight: .bold)
  static let calendarToolbarButtonFont = Font.system(size: 15, weight: .semibold)
  static let editButtonCornerRadius: CGFloat = 10
  static let copyIconSize: CGFloat = 18
  static let copyButtonSize: CGFloat = 28
  static let releaseLogButtonFont = Font.system(size: 16, weight: .semibold)
  static let releaseLogDateFont = Font.system(size: 16, weight: .semibold)
  static let releaseLogMetaFont = Font.system(size: 14, weight: .regular)
  static let releaseLogNoteFont = Font.system(size: 14, weight: .regular)
  static let releaseLogSheetTitleFont = Font.system(size: 18, weight: .semibold)
  static let releaseLogOutcomeFont = Font.system(size: 14, weight: .semibold)
  static let releaseLogCounterFont = Font.system(size: 12, weight: .regular)
  static let modalCornerRadius: CGFloat = 16
  static let modalButtonHeight: CGFloat = 44
  static let modalButtonCornerRadius: CGFloat = 22
  static let releaseLogButtonHeight: CGFloat = 48
  static let releaseLogSpacing: CGFloat = 16
  static let releaseLogCardSpacing: CGFloat = 8
  static let releaseLogCardInnerSpacing: CGFloat = 8
  static let releaseLogCardBorderWidth: CGFloat = 1.2
  static let releaseLogSheetSpacing: CGFloat = 16
  static let releaseLogSheetFieldSpacing: CGFloat = 12
  static let releaseLogOutcomeHeight: CGFloat = 36
  static let releaseLogMemoHeight: CGFloat = 80

  static let dateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateFormat = "yyyy/MM/dd HH:mm"
    return formatter
  }()

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
    chipHeight: chipHeight,
    chipFont: chipFont,
    chipText: chipText,
    chipFill: chipFill,
    closeButtonFont: calendarToolbarButtonFont
  )
}

private struct DetailTabButton: View {
  let title: String
  let isSelected: Bool
  var badgeCount: Int? = nil
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack(alignment: .bottom) {
        HStack(spacing: 6) {
          Text(title)
            .font(isSelected ? DetailStyle.tabSelectedFont : DetailStyle.tabFont)
            .foregroundColor(
              isSelected ? DetailStyle.tabSelectedText : DetailStyle.tabUnselectedText)
          if let badgeCount {
            DetailCountBadge(count: badgeCount)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        Rectangle()
          .fill(isSelected ? DetailStyle.tabIndicatorFill : .clear)
          .frame(height: DetailStyle.tabIndicatorHeight)
      }
    }
    .buttonStyle(.plain)
  }
}

private struct ReleaseLogEntry: Identifiable {
  let id: UUID
  let date: Date
  let mediaReleaseDate: Date?
  let projectName: String
  let outcome: ReleaseLogOutcome?
  let chips: [ReleaseLogChip]
  let note: String

  var dateText: String {
    DetailStyle.dateTimeFormatter.string(from: date)
  }

  var mediaReleaseText: String? {
    guard let mediaReleaseDate else { return nil }
    return DetailStyle.dateFormatter.string(from: mediaReleaseDate)
  }

  var displayProjectName: String {
    projectName.isEmpty ? "未設定" : projectName
  }

  var displayNote: String {
    note.isEmpty ? "メモなし" : note
  }
}

private struct ReleaseLogDraft: Equatable {
  var talkedAt: Date = Date()
  var mediaReleaseDate: Date? = nil
  var projectName: String = ""
  var outcome: ReleaseLogOutcome? = nil
  var memo: String = ""
}

private struct ReleaseLogChip {
  let label: String
  let style: ReleaseLogChipStyle
}

private enum ReleaseLogChipStyle {
  case neutral
  case success

  var background: Color {
    switch self {
    case .neutral:
      return DetailStyle.chipFill
    case .success:
      return Color(hex: "E8F5E9")
    }
  }

  var textColor: Color {
    switch self {
    case .neutral:
      return DetailStyle.chipText
    case .success:
      return Color(hex: "2E7D32")
    }
  }
}

extension ReleaseLogOutcome {
  fileprivate var chipStyle: ReleaseLogChipStyle {
    switch self {
    case .hit: return .success
    case .soSo: return .neutral
    case .shelved: return .neutral
    }
  }

  fileprivate var iconName: String {
    switch self {
    case .hit: return "circle"
    case .soSo: return "triangle"
    case .shelved: return "xmark"
    }
  }

  fileprivate var iconColor: Color {
    switch self {
    case .hit: return HomeStyle.fabRed
    case .soSo: return Color(hex: "1F6F4A")
    case .shelved: return Color(hex: "5B2C83")
    }
  }

  fileprivate var selectedFill: Color {
    switch self {
    case .hit: return Color(hex: "FAD2D1")
    case .soSo: return Color(hex: "D6EFE3")
    case .shelved: return Color(hex: "E5D7F2")
    }
  }
}

private struct ReleaseLogCard: View {
  let entry: ReleaseLogEntry
  let onEdit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: DetailStyle.releaseLogCardInnerSpacing) {
      HStack(alignment: .top, spacing: 8) {
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.dateText)
            .font(DetailStyle.releaseLogDateFont)
            .foregroundColor(DetailStyle.headerText)
          Text(entry.displayProjectName)
            .font(DetailStyle.releaseLogMetaFont)
            .foregroundColor(DetailStyle.labelText)
          if let mediaReleaseText = entry.mediaReleaseText {
            Text("公開日 \(mediaReleaseText)")
              .font(DetailStyle.releaseLogMetaFont)
              .foregroundColor(DetailStyle.labelText.opacity(0.8))
          }
        }

        Spacer()

        Button {
          onEdit()
        } label: {
          Image(systemName: "square.and.pencil")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(DetailStyle.labelText)
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
      }

      if !entry.chips.isEmpty {
        FlowLayout(spacing: DetailStyle.chipSpacing) {
          ForEach(entry.chips.indices, id: \.self) { index in
            let chip = entry.chips[index]
            Text(chip.label)
              .font(DetailStyle.chipFont)
              .foregroundColor(chip.style.textColor)
              .padding(.horizontal, 12)
              .frame(height: DetailStyle.chipHeight)
              .background(chip.style.background)
              .clipShape(Capsule())
          }
        }
      }

      Text(entry.displayNote)
        .font(DetailStyle.releaseLogNoteFont)
        .foregroundColor(DetailStyle.releaseLogNoteColor)
        .lineSpacing(2)
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
        .stroke(DetailStyle.inputBorder, lineWidth: DetailStyle.releaseLogCardBorderWidth)
        .background(
          RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
            .fill(Color.white)
        )
    )
  }
}

private struct ReleaseLogSheet: View {
  @Binding var draft: ReleaseLogDraft
  let isEditing: Bool
  let onSave: () -> Void
  let onDelete: () -> Void
  let onCancel: () -> Void

  private let maxMemoCount = 80
  @State private var showsDeleteConfirm = false

  private var remainingCount: Int {
    maxMemoCount - draft.memo.count
  }

  private var canSave: Bool {
    !draft.projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && draft.outcome != nil
  }

  var body: some View {
    ZStack {
      ScrollView(.vertical, showsIndicators: true) {
        VStack(alignment: .leading, spacing: DetailStyle.releaseLogSheetSpacing) {
          HStack {
            Text(isEditing ? "記録を編集" : "記録を追加")
              .font(DetailStyle.releaseLogSheetTitleFont)
              .foregroundColor(DetailStyle.headerText)
            Spacer()
            if isEditing {
              Button {
                showsDeleteConfirm = true
              } label: {
                Image(systemName: "trash")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundColor(DetailStyle.modalDestructiveText)
                  .frame(width: 32, height: 32)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.top, 4)

          VStack(alignment: .leading, spacing: DetailStyle.releaseLogSheetFieldSpacing) {
            ReleaseLogDateRow(title: "話した日", date: $draft.talkedAt, required: true)
            ReleaseLogOptionalDateRow(title: "メディア公開日", date: $draft.mediaReleaseDate)

            VStack(alignment: .leading, spacing: 6) {
              DetailFieldLabel(title: "企画名", required: true)
              TextField("企画名を入力", text: $draft.projectName)
                .font(DetailStyle.inputFont)
                .foregroundColor(DetailStyle.inputText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(height: DetailStyle.inputHeight)
                .background(
                  RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
                    .stroke(DetailStyle.inputBorder, lineWidth: DetailStyle.inputBorderWidth)
                )
            }

            VStack(alignment: .leading, spacing: 6) {
              DetailFieldLabel(title: "手応え", required: true)
              HStack(spacing: 10) {
                ForEach(ReleaseLogOutcome.allCases, id: \.self) { outcome in
                  Button {
                    draft.outcome = outcome
                  } label: {
                    HStack(spacing: 6) {
                      Image(systemName: outcome.iconName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(outcome.iconColor)
                      Text(outcome.label)
                        .font(DetailStyle.releaseLogOutcomeFont)
                        .foregroundColor(
                          draft.outcome == outcome ? outcome.iconColor : DetailStyle.labelText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: DetailStyle.releaseLogOutcomeHeight)
                    .background(
                      Capsule()
                        .fill(
                          draft.outcome == outcome
                            ? outcome.selectedFill : DetailStyle.releaseLogOutcomeFill)
                    )
                  }
                  .buttonStyle(.plain)
                }
              }
            }

            VStack(alignment: .leading, spacing: 6) {
              DetailFieldLabel(title: "一言メモ")
              ZStack(alignment: .topLeading) {
                if draft.memo.isEmpty {
                  Text("簡単にメモを残す")
                    .font(DetailStyle.inputFont)
                    .foregroundColor(DetailStyle.labelText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }

                TextEditor(text: $draft.memo)
                  .font(DetailStyle.inputFont)
                  .foregroundColor(DetailStyle.inputText)
                  .padding(8)
                  .scrollContentBackground(.hidden)
                  .onChange(of: draft.memo) { _, newValue in
                    if newValue.count > maxMemoCount {
                      draft.memo = String(newValue.prefix(maxMemoCount))
                    }
                  }
              }
              .frame(height: DetailStyle.releaseLogMemoHeight)
              .background(
                RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
                  .stroke(DetailStyle.inputBorder, lineWidth: DetailStyle.inputBorderWidth)
              )

              HStack {
                Spacer()
                Text("残り \(max(0, remainingCount))")
                  .font(DetailStyle.releaseLogCounterFont)
                  .foregroundColor(DetailStyle.labelText)
              }
            }
          }

          Button {
            onSave()
          } label: {
            Text("保存")
              .font(DetailStyle.modalButtonFont)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .frame(height: DetailStyle.modalButtonHeight)
              .background(DetailStyle.modalPrimaryFill)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
          .disabled(!canSave)
          .opacity(canSave ? 1 : 0.6)

          Button("キャンセル") {
            onCancel()
          }
          .font(DetailStyle.modalButtonFont)
          .foregroundColor(DetailStyle.labelText)
          .frame(maxWidth: .infinity)
        }
        .padding(20)
      }
      .background(Color.white)

      if showsDeleteConfirm {
        deleteConfirmView
      }
    }
    .background(Color.white)
    .contentShape(Rectangle())
    .onTapGesture {
      hideKeyboard()
    }
  }

  private var deleteConfirmView: some View {
    ZStack {
      Color.black.opacity(0.25)
        .ignoresSafeArea()
        .onTapGesture {
          showsDeleteConfirm = false
        }

      VStack(spacing: 20) {
        VStack(spacing: 12) {
          Text("削除しますか？")
            .font(DetailStyle.modalTitleFont)
            .foregroundColor(DetailStyle.headerText)
          Text("この記録は元に戻せません。")
            .font(DetailStyle.modalBodyFont)
            .foregroundColor(DetailStyle.labelText)
            .lineSpacing(4)
            .multilineTextAlignment(.center)
        }

        HStack(spacing: 12) {
          Button("キャンセル") {
            showsDeleteConfirm = false
          }
          .font(DetailStyle.modalButtonFont)
          .foregroundColor(DetailStyle.labelText)
          .frame(maxWidth: .infinity)
          .frame(height: DetailStyle.modalButtonHeight)
          .overlay(
            Capsule()
              .stroke(DetailStyle.modalButtonBorder, lineWidth: 1)
          )

          Button("削除") {
            showsDeleteConfirm = false
            onDelete()
          }
          .font(DetailStyle.modalButtonFont)
          .foregroundColor(Color.white)
          .frame(maxWidth: .infinity)
          .frame(height: DetailStyle.modalButtonHeight)
          .background(DetailStyle.modalDestructiveFill)
          .clipShape(Capsule())
        }
      }
      .padding(22)
      .background(DetailStyle.modalBackground)
      .clipShape(RoundedRectangle(cornerRadius: DetailStyle.modalCornerRadius, style: .continuous))
      .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
      .padding(.horizontal, 32)
    }
  }
}

private struct ReleaseLogDateRow: View {
  let title: String
  @Binding var date: Date
  let required: Bool
  @State private var showsPicker = false
  @State private var tempDate = Date()

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      DetailFieldLabel(title: title, required: required)
      Button {
        tempDate = date
        showsPicker = true
      } label: {
        HStack {
          Text(DetailStyle.dateFormatter.string(from: date))
            .font(DetailStyle.inputFont)
            .foregroundColor(DetailStyle.inputText)
          Spacer()
          Image(systemName: "calendar")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(DetailStyle.chipText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: DetailStyle.inputHeight)
        .background(
          RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
            .stroke(DetailStyle.inputBorder, lineWidth: DetailStyle.inputBorderWidth)
        )
      }
      .buttonStyle(.plain)
      .sheet(isPresented: $showsPicker) {
        NavigationStack {
          VStack(spacing: DetailStyle.calendarSheetSpacing) {
            DatePicker("", selection: $tempDate, displayedComponents: .date)
              .datePickerStyle(.graphical)
              .labelsHidden()
              .tint(DetailStyle.calendarTint)
              .padding(.horizontal, 4)

            Button("決定") {
              date = tempDate
              showsPicker = false
            }
            .font(DetailStyle.modalButtonFont)
            .foregroundColor(Color.white)
            .padding(.horizontal, 24)
            .frame(height: DetailStyle.modalButtonHeight)
            .background(DetailStyle.modalPrimaryFill)
            .clipShape(Capsule())
          }
          .padding(.top, 8)
          .padding(.bottom, 8)
          .navigationTitle(title)
          .toolbar {
            ToolbarItem(placement: .topBarLeading) {
              Button {
                showsPicker = false
              } label: {
                CalendarToolbarButtonLabel(title: "閉じる", font: DetailStyle.calendarToolbarButtonFont, fillColor: DetailStyle.calendarToolbarButtonFill, textColor: DetailStyle.calendarToolbarButtonText)
              }
              .buttonStyle(.plain)
            }
          }
        }
        .presentationDetents([.height(DetailStyle.calendarSheetHeight)])
        .presentationDragIndicator(.visible)
      }
    }
  }
}

private struct ReleaseLogOptionalDateRow: View {
  let title: String
  @Binding var date: Date?
  @State private var showsPicker = false
  @State private var tempDate = Date()

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      DetailFieldLabel(title: title)
      Button {
        tempDate = date ?? Date()
        showsPicker = true
      } label: {
        HStack {
          Text(date.map { DetailStyle.dateFormatter.string(from: $0) } ?? "未設定")
            .font(DetailStyle.inputFont)
            .foregroundColor(date == nil ? DetailStyle.labelText : DetailStyle.inputText)
          Spacer()
          Image(systemName: "calendar")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(DetailStyle.chipText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: DetailStyle.inputHeight)
        .background(
          RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
            .stroke(DetailStyle.inputBorder, lineWidth: DetailStyle.inputBorderWidth)
        )
      }
      .buttonStyle(.plain)
      .sheet(isPresented: $showsPicker) {
        NavigationStack {
          VStack(spacing: DetailStyle.calendarSheetSpacing) {
            DatePicker("", selection: $tempDate, displayedComponents: .date)
              .datePickerStyle(.graphical)
              .labelsHidden()
              .tint(DetailStyle.calendarTint)
              .padding(.horizontal, 4)

            Button("決定") {
              date = tempDate
              showsPicker = false
            }
            .font(DetailStyle.modalButtonFont)
            .foregroundColor(Color.white)
            .padding(.horizontal, 24)
            .frame(height: DetailStyle.modalButtonHeight)
            .background(DetailStyle.modalPrimaryFill)
            .clipShape(Capsule())
          }
          .padding(.top, 8)
          .padding(.bottom, 8)
          .navigationTitle(title)
          .toolbar {
            ToolbarItem(placement: .topBarLeading) {
              Button {
                showsPicker = false
              } label: {
                CalendarToolbarButtonLabel(title: "閉じる", font: DetailStyle.calendarToolbarButtonFont, fillColor: DetailStyle.calendarToolbarButtonFill, textColor: DetailStyle.calendarToolbarButtonText)
              }
              .buttonStyle(.plain)
            }
            ToolbarItem(placement: .topBarTrailing) {
              Button {
                date = nil
                showsPicker = false
              } label: {
                CalendarToolbarButtonLabel(
                  title: "クリア",
                  font: DetailStyle.calendarToolbarButtonFont,
                  fillColor: DetailStyle.calendarToolbarButtonFill,
                  textColor: DetailStyle.calendarToolbarButtonDestructiveText
                )
              }
              .buttonStyle(.plain)
            }
          }
        }
        .presentationDetents([.height(DetailStyle.calendarSheetHeight)])
        .presentationDragIndicator(.visible)
      }
    }
  }
}

private struct DetailCountBadge: View {
  let count: Int

  var body: some View {
    Text("\(count)")
      .font(.system(size: 11, weight: .bold))
      .foregroundColor(.white)
      .padding(.horizontal, 6)
      .frame(minWidth: 18, minHeight: 18)
      .background(HomeStyle.fabRed)
      .clipShape(Circle())
  }
}

private struct DetailStatusBadge: View {
  let isUnlocked: Bool

  private var label: String {
    isUnlocked ? "解禁OK" : "解禁前"
  }

  private var fill: Color {
    isUnlocked ? HomeStyle.segmentSelectedFill : HomeStyle.lockedAccent
  }

  private var border: Color {
    isUnlocked ? HomeStyle.cardBorder : HomeStyle.lockedCardBorder
  }

  var body: some View {
    Text(label)
      .font(DetailStyle.badgeFont)
      .foregroundColor(HomeStyle.segmentSelectedText)
      .padding(.horizontal, 12)
      .padding(.vertical, 4)
      .background(
        Capsule()
          .fill(fill)
          .overlay(
            Capsule()
              .stroke(border, lineWidth: DetailStyle.inputBorderWidth)
          )
      )
  }
}

private struct DetailFieldLabel: View {
  let title: String
  var required: Bool = false

  var body: some View {
    HStack(spacing: 2) {
      Text(title)
        .font(DetailStyle.labelFont)
        .foregroundColor(DetailStyle.labelText)
      if required {
        Text("*")
          .font(DetailStyle.labelFont)
          .foregroundColor(DetailStyle.requiredText)
      }
    }
  }
}

private struct ReadOnlyField: View {
  let text: String

  var body: some View {
    Text(text)
      .font(DetailStyle.inputFont)
      .foregroundColor(DetailStyle.inputText)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(height: DetailStyle.inputHeight)
      .background(
        RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
          .fill(DetailStyle.readOnlyFill)
      )
      .overlay(
        RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
          .stroke(DetailStyle.readOnlyBorder, lineWidth: DetailStyle.inputBorderWidth)
      )
  }
}

private struct EditableField: View {
  let placeholder: String
  @Binding var text: String

  var body: some View {
    TextField("", text: $text, prompt: Text(placeholder).foregroundColor(DetailStyle.labelText))
      .font(DetailStyle.inputFont)
      .foregroundColor(DetailStyle.inputText)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(height: DetailStyle.inputHeight)
      .background(
        RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
          .fill(Color.white)
      )
      .overlay(
        RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
          .stroke(DetailStyle.inputBorder, lineWidth: DetailStyle.inputBorderWidth)
      )
  }
}

private struct ReadOnlyTextArea: View {
  let text: String

  var body: some View {
    Text(text)
      .font(DetailStyle.inputFont)
      .foregroundColor(DetailStyle.inputText)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .frame(minHeight: DetailStyle.textAreaHeight, alignment: .topLeading)
      .background(
        RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
          .fill(DetailStyle.readOnlyFill)
      )
      .overlay(
        RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
          .stroke(DetailStyle.readOnlyBorder, lineWidth: DetailStyle.inputBorderWidth)
      )
  }
}

private struct EditableTextArea: View {
  let placeholder: String
  @Binding var text: String

  var body: some View {
    ZStack(alignment: .topLeading) {
      if text.isEmpty {
        Text(placeholder)
          .font(DetailStyle.inputFont)
          .foregroundColor(DetailStyle.labelText)
          .padding(.horizontal, 12)
          .padding(.vertical, 12)
      }

      TextEditor(text: $text)
        .font(DetailStyle.inputFont)
        .foregroundColor(DetailStyle.inputText)
        .padding(8)
        .scrollContentBackground(.hidden)
    }
    .frame(minHeight: DetailStyle.textAreaHeight, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
        .fill(Color.white)
    )
    .overlay(
      RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
        .stroke(DetailStyle.inputBorder, lineWidth: DetailStyle.inputBorderWidth)
    )
  }
}

private struct DetailDateField: View {
  @Binding var date: Date
  @State private var showsPicker = false
  @State private var tempDate = Date()

  var body: some View {
    Button {
      tempDate = date
      showsPicker = true
    } label: {
      HStack {
        Text(DetailStyle.dateFormatter.string(from: date))
          .font(DetailStyle.inputFont)
          .foregroundColor(DetailStyle.inputText)
        Spacer(minLength: 0)
        Image(systemName: "calendar")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(DetailStyle.chipText)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(height: DetailStyle.inputHeight)
      .background(
        RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
          .fill(Color.white)
      )
      .overlay(
        RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
          .stroke(DetailStyle.inputBorder, lineWidth: DetailStyle.inputBorderWidth)
      )
    }
    .buttonStyle(.plain)
    .sheet(isPresented: $showsPicker) {
      NavigationStack {
        VStack(spacing: DetailStyle.calendarSheetSpacing) {
          DatePicker("", selection: $tempDate, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(DetailStyle.calendarTint)
            .padding(.horizontal, 4)

          Button("決定") {
            date = tempDate
            showsPicker = false
          }
          .font(DetailStyle.modalButtonFont)
          .foregroundColor(Color.white)
          .padding(.horizontal, 24)
          .frame(height: 48)
          .background(HomeStyle.fabRed)
          .clipShape(Capsule())
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .navigationTitle("日付を選択")
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              showsPicker = false
            } label: {
              CalendarToolbarButtonLabel(title: "閉じる", font: DetailStyle.calendarToolbarButtonFont, fillColor: DetailStyle.calendarToolbarButtonFill, textColor: DetailStyle.calendarToolbarButtonText)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .presentationDetents([.height(DetailStyle.calendarSheetHeight)])
      .presentationDragIndicator(.visible)
    }
  }
}

private struct DetailOptionalDateField: View {
  let title: String
  @Binding var date: Date?
  let placeholder: String
  @State private var showsPicker = false
  @State private var tempDate = Date()

  var body: some View {
    Button {
      tempDate = date ?? Date()
      showsPicker = true
    } label: {
      HStack {
        Text(date.map { DetailStyle.dateFormatter.string(from: $0) } ?? placeholder)
          .font(DetailStyle.inputFont)
          .foregroundColor(date == nil ? DetailStyle.labelText : DetailStyle.inputText)
        Spacer(minLength: 0)
        Image(systemName: "calendar")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(DetailStyle.chipText)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(height: DetailStyle.inputHeight)
      .background(
        RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
          .fill(Color.white)
      )
      .overlay(
        RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
          .stroke(DetailStyle.inputBorder, lineWidth: DetailStyle.inputBorderWidth)
      )
    }
    .buttonStyle(.plain)
    .sheet(isPresented: $showsPicker) {
      NavigationStack {
        VStack(spacing: DetailStyle.calendarSheetSpacing) {
          DatePicker("", selection: $tempDate, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(DetailStyle.calendarTint)
            .padding(.horizontal, 4)

          Button("決定") {
            date = tempDate
            showsPicker = false
          }
          .font(DetailStyle.modalButtonFont)
          .foregroundColor(Color.white)
          .padding(.horizontal, 24)
          .frame(height: DetailStyle.modalButtonHeight)
          .background(DetailStyle.modalPrimaryFill)
          .clipShape(Capsule())
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .navigationTitle(title)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              showsPicker = false
            } label: {
              CalendarToolbarButtonLabel(title: "閉じる", font: DetailStyle.calendarToolbarButtonFont, fillColor: DetailStyle.calendarToolbarButtonFill, textColor: DetailStyle.calendarToolbarButtonText)
            }
            .buttonStyle(.plain)
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              date = nil
              showsPicker = false
            } label: {
              CalendarToolbarButtonLabel(
                title: "クリア",
                font: DetailStyle.calendarToolbarButtonFont,
                fillColor: DetailStyle.calendarToolbarButtonFill,
                textColor: DetailStyle.calendarToolbarButtonDestructiveText
              )
            }
            .buttonStyle(.plain)
          }
        }
      }
      .presentationDetents([.height(DetailStyle.calendarSheetHeight)])
      .presentationDragIndicator(.visible)
    }
  }
}

private struct DetailChipSection: View {
  let title: String
  let chips: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: DetailStyle.fieldSpacing) {
      DetailFieldLabel(title: title)
      DetailChipWrap(chips: chips)
    }
  }
}

private struct DetailChipWrap: View {
  let chips: [String]

  var body: some View {
    FlowLayout(spacing: DetailStyle.chipSpacing) {
      ForEach(chips, id: \.self) { chip in
        DetailChip(title: chip)
      }
    }
  }
}

private struct DetailChip: View {
  let title: String

  var body: some View {
    Text(title)
      .font(DetailStyle.chipFont)
      .foregroundColor(DetailStyle.chipText)
      .padding(.horizontal, 12)
      .frame(height: DetailStyle.chipHeight)
      .background(DetailStyle.chipFill)
      .clipShape(Capsule())
  }
}

private struct EmotionPresetDetailChip: View {
  let title: String
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 6) {
      if isSelected {
        Image(systemName: "checkmark")
          .font(.system(size: 11, weight: .semibold))
      }
      Text(title)
        .font(DetailStyle.chipFont)
    }
      .foregroundColor(isSelected ? DetailStyle.emotionPresetSelectedText : DetailStyle.chipText)
      .padding(.horizontal, 12)
      .frame(height: DetailStyle.chipHeight)
      .background(
        Capsule()
          .fill(isSelected ? DetailStyle.emotionPresetSelectedFill : DetailStyle.chipFill)
      )
      .overlay(
        Capsule()
          .stroke(
            isSelected ? DetailStyle.emotionPresetSelectedBorder : DetailStyle.inputBorder,
            lineWidth: isSelected ? 1.2 : 1
          )
      )
  }
}

private struct DetailChipInputField: View {
  let placeholder: String
  @Binding var text: String
  @Binding var selection: String?
  var isFocused: Binding<Bool>? = nil
  var onSubmit: (() -> Void)? = nil

  @FocusState private var focused: Bool

  var body: some View {
    HStack(spacing: 6) {
      if let selection {
        DetailSelectedChip(title: selection) {
          self.selection = nil
          text = ""
        }
      } else {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(DetailStyle.labelText))
          .font(DetailStyle.inputFont)
          .foregroundColor(DetailStyle.inputText)
          .frame(maxWidth: .infinity, alignment: .leading)
          .focused($focused)
          .onChange(of: focused) { newValue in
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
    .frame(height: DetailStyle.inputHeight)
    .background(
      RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
        .fill(Color.white)
    )
    .overlay(
      RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
        .stroke(DetailStyle.inputBorder, lineWidth: DetailStyle.inputBorderWidth)
    )
  }
}

private struct DetailMultiChipInputField: View {
  let placeholder: String
  @Binding var text: String
  @Binding var selections: [String]
  let maxSelections: Int
  let onCommit: () -> Void
  let onRemove: (String) -> Void
  // optional external binding to track focus
  var isFocused: Binding<Bool>? = nil

  @FocusState private var focused: Bool

  var body: some View {
    let isAtLimit = selections.count >= maxSelections
    let promptText = selections.isEmpty ? placeholder : ""

    FlowLayout(spacing: 6) {
      ForEach(selections, id: \.self) { item in
        DetailSelectedChip(title: item) {
          onRemove(item)
        }
      }
      if !isAtLimit {
        TextField("", text: $text, prompt: Text(promptText).foregroundColor(DetailStyle.labelText))
          .font(DetailStyle.inputFont)
          .foregroundColor(DetailStyle.inputText)
          .frame(minWidth: 80, alignment: .leading)
          .focused($focused)
          .onChange(of: focused) { newValue in
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
    .frame(minHeight: DetailStyle.inputHeight, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
        .fill(Color.white)
    )
    .overlay(
      RoundedRectangle(cornerRadius: DetailStyle.inputCornerRadius)
        .stroke(DetailStyle.inputBorder, lineWidth: DetailStyle.inputBorderWidth)
    )
  }
}

private struct DetailSelectedChip: View {
  let title: String
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      Text(title)
        .font(DetailStyle.labelFont)
        .foregroundColor(DetailStyle.chipText)
      Button(action: onRemove) {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(DetailStyle.chipText)
          .frame(width: 16, height: 16)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 12)
    .frame(height: DetailStyle.chipHeight)
    .background(DetailStyle.chipFill)
    .clipShape(Capsule())
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
