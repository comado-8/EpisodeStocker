import SwiftUI

enum ScreenStyle {
    static func contentWidth(
        totalWidth: CGFloat,
        baseContentWidth: CGFloat,
        regularContentWidth: CGFloat,
        regularLayoutThreshold: CGFloat,
        horizontalPadding: CGFloat
    ) -> CGFloat {
        let maxWidth = totalWidth - (horizontalPadding * 2)
        guard totalWidth >= regularLayoutThreshold else {
            return min(baseContentWidth, maxWidth)
        }
        return min(regularContentWidth, maxWidth)
    }
}
