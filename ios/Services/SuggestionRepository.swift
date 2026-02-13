import Foundation

protocol SuggestionRepository {
  func fetch(fieldType: String, query: String?, includeDeleted: Bool) -> [Suggestion]
  func softDelete(id: UUID)
  func restore(id: UUID)
  func bumpUsage(id: UUID)
  // convenience: create or bump usage for a value
  func upsert(fieldType: String, value: String)
}
