import SwiftUI

struct HomeAdvancedFilterSheet: View {
    @Binding var draft: HomeAdvancedFilterDraft
    let onApply: () -> Void
    let onClear: () -> Void

    private var talkedStartDateEnabled: Binding<Bool> {
        Binding(
            get: { draft.startDate != nil },
            set: { enabled in
                if enabled {
                    draft.startDate = draft.startDate ?? Date()
                } else {
                    draft.startDate = nil
                }
            }
        )
    }

    private var talkedEndDateEnabled: Binding<Bool> {
        Binding(
            get: { draft.endDate != nil },
            set: { enabled in
                if enabled {
                    draft.endDate = draft.endDate ?? Date()
                } else {
                    draft.endDate = nil
                }
            }
        )
    }

    private var talkedStartDateBinding: Binding<Date> {
        Binding(
            get: { draft.startDate ?? Date() },
            set: { draft.startDate = $0 }
        )
    }

    private var talkedEndDateBinding: Binding<Date> {
        Binding(
            get: { draft.endDate ?? Date() },
            set: { draft.endDate = $0 }
        )
    }

    private var episodeDateStartEnabled: Binding<Bool> {
        Binding(
            get: { draft.episodeDateStart != nil },
            set: { enabled in
                if enabled {
                    draft.episodeDateStart = draft.episodeDateStart ?? Date()
                } else {
                    draft.episodeDateStart = nil
                }
            }
        )
    }

    private var episodeDateEndEnabled: Binding<Bool> {
        Binding(
            get: { draft.episodeDateEnd != nil },
            set: { enabled in
                if enabled {
                    draft.episodeDateEnd = draft.episodeDateEnd ?? Date()
                } else {
                    draft.episodeDateEnd = nil
                }
            }
        )
    }

    private var episodeDateStartBinding: Binding<Date> {
        Binding(
            get: { draft.episodeDateStart ?? Date() },
            set: { draft.episodeDateStart = $0 }
        )
    }

    private var episodeDateEndBinding: Binding<Date> {
        Binding(
            get: { draft.episodeDateEnd ?? Date() },
            set: { draft.episodeDateEnd = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("詳細検索")
                .font(AppTypography.formScreenTitle)
                .foregroundColor(HomeStyle.advancedFilterSectionTitle)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: HomeStyle.advancedFilterSectionSpacing) {
                talkCountSection
                episodeDateRangeSection
                talkedDateRangeSection
                mediaTypeSection
                reactionSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            HStack(spacing: 10) {
                Button {
                    onClear()
                } label: {
                    Text("Clear")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(HomeStyle.segmentText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            Capsule()
                                .stroke(HomeStyle.searchBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onApply()
                } label: {
                    Text("Apply")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(HomeStyle.fabRed)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(HomeStyle.background)
    }

    private var talkCountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("話した回数")
            FlowLayout(spacing: 8) {
                ForEach(HomeAdvancedFilterDraft.TalkCountPreset.allCases, id: \.self) { preset in
                    let isSelected = draft.talkCountPreset == preset
                    Button {
                        draft.talkCountPreset = isSelected ? nil : preset
                    } label: {
                        chipLabel(
                            title: preset.rawValue,
                            isSelected: isSelected
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var talkedDateRangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("話した日")
            Text("開始日または終了日を指定すると有効になります")
                .font(AppTypography.subtext)
                .foregroundColor(HomeStyle.advancedFilterHelperText)

            VStack(alignment: .leading, spacing: 10) {
                Toggle("開始日を指定", isOn: talkedStartDateEnabled)
                    .font(AppTypography.subtextEmphasis)
                    .foregroundColor(HomeStyle.searchChipText)
                    .toggleStyle(SwitchToggleStyle(tint: HomeStyle.fabRed))

                if draft.startDate != nil {
                    DatePicker(
                        "開始日",
                        selection: talkedStartDateBinding,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .font(AppTypography.subtextEmphasis)
                    .foregroundColor(HomeStyle.searchChipText)
                }

                Toggle("終了日を指定", isOn: talkedEndDateEnabled)
                    .font(AppTypography.subtextEmphasis)
                    .foregroundColor(HomeStyle.searchChipText)
                    .toggleStyle(SwitchToggleStyle(tint: HomeStyle.fabRed))

                if draft.endDate != nil {
                    DatePicker(
                        "終了日",
                        selection: talkedEndDateBinding,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .font(AppTypography.subtextEmphasis)
                    .foregroundColor(HomeStyle.searchChipText)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(HomeStyle.searchFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(HomeStyle.searchBorder, lineWidth: 1)
                    )
            )
        }
    }

    private var episodeDateRangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("エピソード日付")
            Text("開始日または終了日を指定すると有効になります")
                .font(AppTypography.subtext)
                .foregroundColor(HomeStyle.advancedFilterHelperText)

            VStack(alignment: .leading, spacing: 10) {
                Toggle("開始日を指定", isOn: episodeDateStartEnabled)
                    .font(AppTypography.subtextEmphasis)
                    .foregroundColor(HomeStyle.searchChipText)
                    .toggleStyle(SwitchToggleStyle(tint: HomeStyle.fabRed))

                if draft.episodeDateStart != nil {
                    DatePicker(
                        "開始日",
                        selection: episodeDateStartBinding,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .font(AppTypography.subtextEmphasis)
                    .foregroundColor(HomeStyle.searchChipText)
                }

                Toggle("終了日を指定", isOn: episodeDateEndEnabled)
                    .font(AppTypography.subtextEmphasis)
                    .foregroundColor(HomeStyle.searchChipText)
                    .toggleStyle(SwitchToggleStyle(tint: HomeStyle.fabRed))

                if draft.episodeDateEnd != nil {
                    DatePicker(
                        "終了日",
                        selection: episodeDateEndBinding,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .font(AppTypography.subtextEmphasis)
                    .foregroundColor(HomeStyle.searchChipText)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(HomeStyle.searchFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(HomeStyle.searchBorder, lineWidth: 1)
                    )
            )
        }
    }

    private var mediaTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("媒体タイプ")
            FlowLayout(spacing: 8) {
                ForEach(ReleaseLogMediaPreset.allCases) { media in
                    let isSelected = draft.mediaTypes.contains(media.rawValue)
                    Button {
                        if isSelected {
                            draft.mediaTypes.remove(media.rawValue)
                        } else {
                            draft.mediaTypes.insert(media.rawValue)
                        }
                    } label: {
                        chipLabel(
                            title: media.rawValue,
                            isSelected: isSelected
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var reactionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("リアクション")
            FlowLayout(spacing: 8) {
                ForEach(ReleaseLogOutcome.allCases) { outcome in
                    let isSelected = draft.reactions.contains(outcome)
                    Button {
                        if isSelected {
                            draft.reactions.remove(outcome)
                        } else {
                            draft.reactions.insert(outcome)
                        }
                    } label: {
                        reactionChipLabel(
                            title: outcome.rawValue,
                            outcome: outcome,
                            isSelected: isSelected
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.bodyEmphasis)
            .foregroundColor(HomeStyle.advancedFilterSectionTitle)
    }

    private func chipLabel(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(AppTypography.subtextEmphasis)
            .foregroundColor(
                isSelected ? HomeStyle.advancedFilterChipSelectedText : HomeStyle.searchChipText
            )
            .padding(.horizontal, HomeStyle.advancedFilterChipHorizontalPadding)
            .frame(height: HomeStyle.advancedFilterChipHeight)
            .background(
                Capsule()
                    .fill(isSelected ? HomeStyle.advancedFilterChipSelectedFill : HomeStyle.searchChipFill)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? HomeStyle.advancedFilterChipSelectedBorder : HomeStyle.searchChipBorder,
                        lineWidth: 1
                    )
            )
    }

    private func reactionChipLabel(
        title: String,
        outcome: ReleaseLogOutcome,
        isSelected: Bool
    ) -> some View {
        let style = reactionStyle(for: outcome)
        return Text(title)
            .font(AppTypography.subtextEmphasis)
            .foregroundColor(isSelected ? style.text : HomeStyle.searchChipText)
            .padding(.horizontal, HomeStyle.advancedFilterChipHorizontalPadding)
            .frame(height: HomeStyle.advancedFilterChipHeight)
            .background(
                Capsule()
                    .fill(isSelected ? style.fill : HomeStyle.searchChipFill)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? style.fill : HomeStyle.searchChipBorder,
                        lineWidth: 1
                    )
            )
    }

    private func reactionStyle(for outcome: ReleaseLogOutcome) -> (text: Color, fill: Color) {
        switch outcome {
        case .hit:
            return (HomeStyle.advancedFilterReactionHitText, HomeStyle.advancedFilterReactionHitFill)
        case .soSo:
            return (HomeStyle.advancedFilterReactionSoSoText, HomeStyle.advancedFilterReactionSoSoFill)
        case .shelved:
            return (
                HomeStyle.advancedFilterReactionShelvedText, HomeStyle.advancedFilterReactionShelvedFill
            )
        }
    }
}

struct HomeAdvancedFilterSheet_Previews: PreviewProvider {
    static var previews: some View {
        HomeAdvancedFilterSheetPreviewWrapper()
            .padding()
            .previewLayout(.sizeThatFits)
    }
}

private struct HomeAdvancedFilterSheetPreviewWrapper: View {
    @State private var draft = HomeAdvancedFilterDraft(
        talkCountPreset: .atLeastOne,
        startDate: Date(),
        endDate: Date(),
        mediaTypes: [ReleaseLogMediaPreset.tv.rawValue],
        reactions: [.hit]
    )

    var body: some View {
        HomeAdvancedFilterSheet(
            draft: $draft,
            onApply: {},
            onClear: {}
        )
    }
}
