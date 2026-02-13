import SwiftUI

enum HomeFont {
    static func bodyLarge() -> Font { .custom("Roboto", size: 16) }
    static func bodyMedium() -> Font { .custom("Roboto", size: 14) }
    static func titleMedium() -> Font { .custom("Roboto-Medium", size: 16) }
    static func labelLarge() -> Font { .custom("Roboto-Medium", size: 14) }
    static func emptyStateTitle() -> Font { .custom("Roboto-Medium", size: 20) }
}
