import SwiftUI

enum HomeFont {
    static func bodyLarge() -> Font { .system(size: 16, weight: .regular) }
    static func bodyMedium() -> Font { .system(size: 14, weight: .regular) }
    static func titleMedium() -> Font { .system(size: 16, weight: .medium) }
    static func labelLarge() -> Font { .system(size: 14, weight: .medium) }
    static func emptyStateTitle() -> Font { .system(size: 20, weight: .medium) }
}
