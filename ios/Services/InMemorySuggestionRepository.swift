import Foundation

final class InMemorySuggestionRepository: SuggestionRepository {
  private var items: [Suggestion]
  private let queue = DispatchQueue(
    label: "InMemorySuggestionRepository.queue", attributes: .concurrent)

  init(seed: [Suggestion] = []) {
    self.items = seed
  }

  func fetch(fieldType: String, query: String?, includeDeleted: Bool) -> [Suggestion] {
    var result: [Suggestion] = []
    queue.sync {
      result = items.filter { s in
        guard s.fieldType == fieldType else { return false }
        if !includeDeleted && s.isDeleted { return false }
        if let q = query, !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          return s.value.localizedCaseInsensitiveContains(q)
        }
        return true
      }
      result.sort { a, b in
        if a.lastUsedAt != b.lastUsedAt { return a.lastUsedAt > b.lastUsedAt }
        if a.usageCount != b.usageCount { return a.usageCount > b.usageCount }
        return a.value < b.value
      }
    }
    return result
  }

  func softDelete(id: UUID) {
    queue.async(flags: .barrier) {
      guard let idx = self.items.firstIndex(where: { $0.id == id }) else { return }
      self.items[idx].isDeleted = true
    }
  }

  func restore(id: UUID) {
    queue.async(flags: .barrier) {
      guard let idx = self.items.firstIndex(where: { $0.id == id }) else { return }
      self.items[idx].isDeleted = false
    }
  }

  func bumpUsage(id: UUID) {
    queue.async(flags: .barrier) {
      guard let idx = self.items.firstIndex(where: { $0.id == id }) else { return }
      self.items[idx].usageCount += 1
      self.items[idx].lastUsedAt = Date()
    }
  }

  func upsert(fieldType: String, value: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    queue.async(flags: .barrier) {
      if let idx = self.items.firstIndex(where: {
        $0.fieldType == fieldType && $0.value.caseInsensitiveCompare(trimmed) == .orderedSame
      }) {
        self.items[idx].usageCount += 1
        self.items[idx].lastUsedAt = Date()
        self.items[idx].isDeleted = false
      } else {
        let item = Suggestion(
          id: UUID(),
          fieldType: fieldType,
          value: trimmed,
          usageCount: 1,
          lastUsedAt: Date(),
          isDeleted: false
        )
        self.items.append(item)
      }
    }
  }
}
