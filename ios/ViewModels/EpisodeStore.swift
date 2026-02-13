import Foundation
import SwiftUI

@MainActor
final class EpisodeStore: ObservableObject {
  let suggestionRepository: SuggestionRepository

  init(suggestionRepository: SuggestionRepository = InMemorySuggestionRepository()) {
    self.suggestionRepository = suggestionRepository
  }
}
