import Foundation

enum SuggestionFieldType: Equatable {
  case person
  case project
  case emotion
  case place
  case tag
  case unknown(String)

  init(_ rawValue: String) {
    switch rawValue {
    case "人物":
      self = .person
    case "企画名":
      self = .project
    case "感情":
      self = .emotion
    case "場所":
      self = .place
    case "タグ":
      self = .tag
    default:
      self = .unknown(rawValue)
    }
  }

  var label: String {
    switch self {
    case .person:
      return "人物"
    case .project:
      return "企画名"
    case .emotion:
      return "感情"
    case .place:
      return "場所"
    case .tag:
      return "タグ"
    case .unknown(let rawValue):
      return rawValue
    }
  }

  var supportsUsageCount: Bool {
    switch self {
    case .person, .project, .place, .tag:
      return true
    case .emotion, .unknown:
      return false
    }
  }

  var protectsUsedEntriesFromDeletion: Bool {
    switch self {
    case .emotion, .unknown:
      return false
    case .person, .project, .place, .tag:
      return true
    }
  }
}
