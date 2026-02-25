import Foundation

enum TagInputConstants {
  static let guideText = "使用可能: 漢字・ひらがな・カナ・英数字（小文字）"

  static func tooLongErrorMessage(limit: Int) -> String {
    "\(limit)文字以内で入力してください"
  }

  static let disallowedCharactersErrorMessage =
    "使用できるのは日本語・英数字のみです（記号・絵文字・空白は使えません）"
}

enum TagInputHelpers {
  static func filteredSuggestions(
    query: String,
    selectedTags: [String],
    registeredTagSuggestions: [String],
    maxItems: Int = 3
  ) -> [String] {
    let normalizedQuery = EpisodePersistence.stripLeadingTagPrefix(
      EpisodePersistence.normalizeTagInputWhileEditing(
        query.trimmingCharacters(in: .whitespacesAndNewlines)
      )
    )
    var seen = Set<String>()
    return registeredTagSuggestions.filter { suggestion in
      guard !selectedTags.contains(suggestion) else { return false }
      let candidate = EpisodePersistence.stripLeadingTagPrefix(
        EpisodePersistence.normalizeTagInputWhileEditing(suggestion)
      )
      if !normalizedQuery.isEmpty && !candidate.contains(normalizedQuery) {
        return false
      }
      return seen.insert(candidate).inserted
    }
    .prefix(maxItems)
    .map { $0 }
  }

  static func validationMessage(for text: String) -> String? {
    guard !text.isEmpty else { return nil }
    return validationMessage(for: EpisodePersistence.validateTagNameInput(text))
  }

  static func validationMessage(for result: TagValidationResult) -> String? {
    switch result {
    case .valid:
      return nil
    case .empty:
      return nil
    case .tooLong(let limit):
      return TagInputConstants.tooLongErrorMessage(limit: limit)
    case .containsDisallowedCharacters:
      return TagInputConstants.disallowedCharactersErrorMessage
    }
  }
}
