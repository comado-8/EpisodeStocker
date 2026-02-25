import SwiftUI

enum AppTypography {
  // 画面タイトル（Large Title）
  static let screenTitle = Font.system(size: 32, weight: .semibold)
  static let formScreenTitle = Font.system(size: 32, weight: .semibold)

  // セクション/カード見出し
  static let sectionTitle = Font.system(size: 20, weight: .semibold)

  // 本文/補足
  static let body = Font.system(size: 17, weight: .regular)
  static let bodyEmphasis = Font.system(size: 17, weight: .semibold)
  static let subtext = Font.system(size: 15, weight: .regular)
  static let subtextEmphasis = Font.system(size: 15, weight: .semibold)
  static let meta = Font.system(size: 13, weight: .regular)
  static let caption = Font.system(size: 12, weight: .regular)

  // タブバー
  static let tabBarLabel = Font.system(size: 12, weight: .medium)
}
