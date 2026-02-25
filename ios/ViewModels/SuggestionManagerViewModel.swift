import Foundation
import SwiftUI

@MainActor
final class SuggestionManagerViewModel: ObservableObject {
  @Published var suggestions: [Suggestion] = []
  @Published var query: String = "" {
    didSet { fetch() }
  }
  @Published var includeDeleted: Bool = false {
    didSet { fetch() }
  }

  private let repository: SuggestionRepository
  private let fieldType: SuggestionFieldType
  private var lastDeletedId: UUID?

  var title: String { fieldType.label }

  init(repository: SuggestionRepository, fieldType: SuggestionFieldType) {
    self.repository = repository
    self.fieldType = fieldType
    fetch()
  }

  convenience init(repository: SuggestionRepository, fieldType: String) {
    self.init(repository: repository, fieldType: SuggestionFieldType(fieldType))
  }

  func fetch() {
    suggestions = repository.fetch(
      fieldType: fieldType.label,
      query: query.isEmpty ? nil : query,
      includeDeleted: includeDeleted
    )
  }

  func softDelete(_ id: UUID) {
    repository.softDelete(id: id)
    lastDeletedId = id
    fetch()
  }

  func restore(_ id: UUID) {
    repository.restore(id: id)
    if lastDeletedId == id { lastDeletedId = nil }
    fetch()
  }

  func undoDelete() {
    guard let id = lastDeletedId else { return }
    repository.restore(id: id)
    lastDeletedId = nil
    fetch()
  }
}
