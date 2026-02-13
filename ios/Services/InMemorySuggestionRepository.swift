import Foundation

final class InMemorySuggestionRepository: SuggestionRepository {
  private var items: [Suggestion]
  private let queue = DispatchQueue(
    label: "InMemorySuggestionRepository.queue", attributes: .concurrent)

  init(seed: [Suggestion] = []) {
    if seed.isEmpty {
      self.items = Self.defaultSeed()
    } else {
      self.items = seed
    }
  }

  private static func defaultSeed() -> [Suggestion] {
    let now = Date()
    return [
      // 人物
      Suggestion(
        id: UUID(), fieldType: "人物", value: "田中さん", usageCount: 5, lastUsedAt: now, isDeleted: false
      ),
      Suggestion(
        id: UUID(), fieldType: "人物", value: "佐藤さん", usageCount: 3,
        lastUsedAt: now.addingTimeInterval(-86400), isDeleted: false),
      Suggestion(
        id: UUID(), fieldType: "人物", value: "鈴木さん", usageCount: 1,
        lastUsedAt: now.addingTimeInterval(-86400 * 2), isDeleted: false),
      // 企画名
      Suggestion(
        id: UUID(), fieldType: "企画名", value: "朝の番組", usageCount: 4,
        lastUsedAt: now.addingTimeInterval(-3600), isDeleted: false),
      Suggestion(
        id: UUID(), fieldType: "企画名", value: "夜のトーク", usageCount: 2,
        lastUsedAt: now.addingTimeInterval(-86400), isDeleted: false),
      Suggestion(
        id: UUID(), fieldType: "企画名", value: "ラジオ企画", usageCount: 1,
        lastUsedAt: now.addingTimeInterval(-86400 * 3), isDeleted: false),
      // 場所
      Suggestion(
        id: UUID(), fieldType: "場所", value: "渋谷", usageCount: 6, lastUsedAt: now, isDeleted: false),
      Suggestion(
        id: UUID(), fieldType: "場所", value: "スタジオ", usageCount: 2,
        lastUsedAt: now.addingTimeInterval(-7200), isDeleted: false),
      Suggestion(
        id: UUID(), fieldType: "場所", value: "カフェ", usageCount: 1,
        lastUsedAt: now.addingTimeInterval(-86400), isDeleted: false),
      // 感情
      Suggestion(
        id: UUID(), fieldType: "感情", value: "嬉しかった", usageCount: 7, lastUsedAt: now,
        isDeleted: false),
      Suggestion(
        id: UUID(), fieldType: "感情", value: "楽しかった", usageCount: 3,
        lastUsedAt: now.addingTimeInterval(-43200), isDeleted: false),
      Suggestion(
        id: UUID(), fieldType: "感情", value: "悲しかった", usageCount: 1,
        lastUsedAt: now.addingTimeInterval(-86400 * 5), isDeleted: false),
    ]
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
