import SwiftUI

struct RegisteredTagSelectionSheetStyle {
  let labelText: Color
  let inputFont: Font
  let inputText: Color
  let inputHeight: CGFloat
  let inputCornerRadius: CGFloat
  let inputBorder: Color
  let inputBorderWidth: CGFloat
  let chipSpacing: CGFloat
  let chipHeight: CGFloat
  let chipFont: Font
  let chipText: Color
  let chipFill: Color
  let closeButtonFont: Font
}

struct RegisteredTagSelectionSheet: View {
  @Environment(\.dismiss) private var dismiss

  let tags: [String]
  let selectedTags: [String]
  let onSelect: (String) -> Void
  let style: RegisteredTagSelectionSheetStyle

  @State private var query = ""

  private var availableTags: [String] {
    var seen = Set<String>()
    var deduplicated: [String] = []
    for tag in tags where !selectedTags.contains(tag) {
      let key = normalizedTagKey(tag)
      guard !key.isEmpty else { continue }
      guard seen.insert(key).inserted else { continue }
      deduplicated.append(tag)
    }
    return deduplicated
  }

  private var filteredTags: [String] {
    let trimmed = normalizedTagKey(query)
    guard !trimmed.isEmpty else { return availableTags }
    return availableTags.filter { tag in
      normalizedTagKey(tag).contains(trimmed)
    }
  }

  private func normalizedTagKey(_ value: String) -> String {
    EpisodePersistence.stripLeadingTagPrefix(
      EpisodePersistence.normalizeTagInputWhileEditing(
        value.trimmingCharacters(in: .whitespacesAndNewlines)
      )
    )
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 12) {
        HStack(spacing: 8) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(style.labelText)
          TextField("タグを検索", text: $query)
            .font(style.inputFont)
            .foregroundColor(style.inputText)
        }
        .padding(.horizontal, 12)
        .frame(height: style.inputHeight)
        .background(
          RoundedRectangle(cornerRadius: style.inputCornerRadius)
            .stroke(style.inputBorder, lineWidth: style.inputBorderWidth)
        )

        ScrollView {
          FlowLayout(spacing: style.chipSpacing) {
            ForEach(filteredTags, id: \.self) { tag in
              Button {
                onSelect(tag)
                dismiss()
              } label: {
                Text(tag)
                  .font(style.chipFont)
                  .foregroundColor(style.chipText)
                  .padding(.horizontal, 12)
                  .frame(height: style.chipHeight)
                  .background(style.chipFill)
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 4)
        }
      }
      .padding(16)
      .navigationTitle("登録タグ選択")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("閉じる") {
            dismiss()
          }
          .font(style.closeButtonFont)
        }
      }
    }
  }
}
