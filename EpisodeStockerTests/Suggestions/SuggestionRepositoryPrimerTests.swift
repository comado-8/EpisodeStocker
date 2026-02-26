import XCTest
@testable import EpisodeStocker

final class SuggestionRepositoryPrimerTests: XCTestCase {
  func testPrimeIfMissingAddsOnlyMissingValues() {
    let personId = UUID()
    let projectId = UUID()
    let repo = InMemorySuggestionRepository(
      seed: [
        Suggestion(
          id: personId,
          fieldType: "人物",
          value: "田中さん",
          usageCount: 4,
          lastUsedAt: Date(timeIntervalSince1970: 10),
          isDeleted: false
        ),
        Suggestion(
          id: projectId,
          fieldType: "企画名",
          value: "朝番組",
          usageCount: 2,
          lastUsedAt: Date(timeIntervalSince1970: 20),
          isDeleted: false
        ),
      ]
    )

    SuggestionRepositoryPrimer.primeIfMissing(
      repository: repo,
      persons: ["田中さん", "佐藤さん"],
      projects: ["朝番組", "夜番組"],
      places: ["スタジオ"],
      tags: ["#新番組"]
    )

    Eventually.assertEventually {
      let persons = repo.fetch(fieldType: "人物", query: nil, includeDeleted: true)
      let projects = repo.fetch(fieldType: "企画名", query: nil, includeDeleted: true)
      let places = repo.fetch(fieldType: "場所", query: nil, includeDeleted: true)
      let tags = repo.fetch(fieldType: "タグ", query: nil, includeDeleted: true)
      guard
        persons.count == 2,
        projects.count == 2,
        places.count == 1,
        tags.count == 1
      else {
        return false
      }

      guard let existingPerson = persons.first(where: { $0.id == personId }) else {
        return false
      }
      guard let existingProject = projects.first(where: { $0.id == projectId }) else {
        return false
      }

      return existingPerson.usageCount == 4
        && existingProject.usageCount == 2
    }
  }

  func testPrimeNormalizesAndDeduplicatesTags() {
    let repo = InMemorySuggestionRepository()

    SuggestionRepositoryPrimer.prime(
      repository: repo,
      fieldType: .tag,
      values: ["#新番組", "新番組", " ＃新番組 "]
    )

    Eventually.assertEventually {
      let tags = repo.fetch(fieldType: "タグ", query: nil, includeDeleted: true)
      return tags.count == 1 && tags.first?.value == "#新番組"
    }
  }
}
