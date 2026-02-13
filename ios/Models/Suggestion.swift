import Foundation

struct Suggestion: Identifiable, Equatable {
  let id: UUID
  let fieldType: String  // e.g. "企画名", "人物", "場所", "感情"
  var value: String
  var usageCount: Int
  var lastUsedAt: Date
  var isDeleted: Bool
}
