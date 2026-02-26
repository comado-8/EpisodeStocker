import Foundation

enum SuggestionRepositoryPrimer {
  static func primeIfMissing(
    repository: SuggestionRepository,
    persons: [String],
    projects: [String],
    places: [String],
    tags: [String]
  ) {
    prime(
      repository: repository,
      fieldType: .person,
      values: persons
    )
    prime(
      repository: repository,
      fieldType: .project,
      values: projects
    )
    prime(
      repository: repository,
      fieldType: .place,
      values: places
    )
    prime(
      repository: repository,
      fieldType: .tag,
      values: tags
    )
  }

  static func prime(
    repository: SuggestionRepository,
    fieldType: SuggestionFieldType,
    values: [String]
  ) {
    if case .unknown = fieldType {
      return
    }

    let existing = Set(
      repository
        .fetch(fieldType: fieldType.label, query: nil, includeDeleted: true)
        .compactMap { normalizedValue($0.value, fieldType: fieldType) }
    )

    var staged = existing
    var seenIncoming = Set<String>()
    for value in values {
      guard
        let canonical = canonicalValue(value, fieldType: fieldType),
        let normalized = normalizedValue(canonical, fieldType: fieldType)
      else {
        continue
      }
      guard seenIncoming.insert(normalized).inserted else { continue }
      guard !staged.contains(normalized) else { continue }

      repository.upsert(fieldType: fieldType.label, value: canonical)
      staged.insert(normalized)
    }
  }

  static func normalizedValue(_ value: String, fieldType: SuggestionFieldType) -> String? {
    switch fieldType {
    case .tag:
      return EpisodePersistence.normalizeTagName(value)?.normalized
    case .person, .project, .emotion, .place:
      return EpisodePersistence.normalizeName(value)?.normalized
    case .unknown:
      return nil
    }
  }

  static func canonicalValue(_ value: String, fieldType: SuggestionFieldType) -> String? {
    switch fieldType {
    case .tag:
      guard let normalized = EpisodePersistence.normalizeTagName(value)?.name else { return nil }
      return "#\(normalized)"
    case .person, .project, .emotion, .place:
      return EpisodePersistence.normalizeName(value)?.name
    case .unknown:
      return nil
    }
  }
}
