import SwiftUI

enum HomeFont {
    static func bodyLarge() -> Font { AppTypography.body }
    static func bodyMedium() -> Font { AppTypography.subtext }
    static func titleMedium() -> Font { AppTypography.sectionTitle }
    static func labelLarge() -> Font { AppTypography.subtextEmphasis }
    static func emptyStateTitle() -> Font { AppTypography.sectionTitle }
    static func tabLabel() -> Font { AppTypography.tabBarLabel }
    static func cardDateYear() -> Font { .system(size: 13, weight: .medium) }
    static func cardDateDay() -> Font { .system(size: 17, weight: .semibold) }
}
