import SwiftUI

enum HomeStyle {
    static let baseContentWidth: CGFloat = 360
    static let horizontalPadding: CGFloat = 16
    static func contentWidth(for totalWidth: CGFloat) -> CGFloat {
        let maxWidth = totalWidth - (horizontalPadding * 2)
        return min(baseContentWidth, maxWidth)
    }
    static let figmaTopInset: CGFloat = 61
    static let sectionSpacing: CGFloat = 8
    static let listSpacing: CGFloat = 10
    static let listCardBorderWidth: CGFloat = 1.5
    static let selectionIndicatorSize: CGFloat = 22
    static let selectionIndicatorSpacing: CGFloat = 12
    static let selectionStatusRowHeight: CGFloat = statusRowHeight
    static let selectionStatusRowHorizontalPadding: CGFloat = 16

    static let searchHeight: CGFloat = 48
    static let searchChipHeight: CGFloat = 32
    static let searchSuggestionRowHeight: CGFloat = 60
    static let dividerHeight: CGFloat = 1

    static let statusRowHeight: CGFloat = 52
    static let segmentedControlWidth: CGFloat = 272
    static let segmentedItemHeight: CGFloat = 40
    static let segmentedCornerRadius: CGFloat = 18

    static let filterButtonSize: CGFloat = 36
    static let filterButtonsWidth: CGFloat = 80

    static let cardHeight: CGFloat = 92
    static let cardCornerRadius: CGFloat = 14
    static let cardContentSpacing: CGFloat = 12
    static let dateBadgeSize: CGFloat = 58

    static let emptyStateCircleSize: CGFloat = 206
    static let emptyStateIconSize: CGFloat = 150
    static let emptyStateTextWidth: CGFloat = 355
    static let emptyStateSpacing: CGFloat = 40
    static let emptyStateTopPadding: CGFloat = 40

    static let fabSize: CGFloat = 64
    static let fabCornerRadius: CGFloat = 32
    static let fabTrailing: CGFloat = 21
    static let fabBottomOffset: CGFloat = 8

    static let tabBarHeight: CGFloat = 83

    static let textPrimary = Color(hex: "3A3742")
    static let textSecondary = Color(hex: "6F7280")
    static let textInput = Color(hex: "343741")

    static let background = Color(hex: "FFFFFF")
    static let outline = Color(hex: "CAC4D0")
    static let searchFill = Color(hex: "F5F6F8")
    static let searchActiveFill = Color(hex: "FFFFFF")
    static let searchBorder = Color(hex: "E1E4EA")
    static let searchActiveBorder = Color(hex: "D4D9E2")
    static let searchChipFill = Color(hex: "F3F4F6")
    static let searchChipBorder = Color(hex: "D1D5DC")
    static let searchChipText = Color(hex: "364153")
    static let searchModeFill = Color(hex: "FDECEC")
    static let searchModeBorder = Color(hex: "F3B4B4")
    static let searchModeText = Color(hex: "8D110E")
    static let searchSuggestionBorder = Color(hex: "E5E7EB")
    static let searchSuggestionDivider = Color(hex: "EEF0F2")
    static let searchSuggestionTitle = textPrimary
    static let searchSuggestionSubtitle = Color(hex: "667085")
    static let searchSuggestionIcon = Color(hex: "364153")

    static let segmentSelectedFill = Color(hex: "FCCECE")
    static let segmentSelectedText = textPrimary
    static let segmentText = Color(hex: "4E4959")
    static let lockedAccent = Color(hex: "D5D5FE")
    static let lockedSegmentText = textPrimary
    static let statusOkSelectedText = Color(hex: "6A2434")
    static let statusLockedSelectedText = Color(hex: "2F2C66")
    static let dateTextUnlocked = Color(hex: "5A1E2B")
    static let dateTextLocked = Color(hex: "25205A")
    static let lockedCardBorder = Color(hex: "AAA9FD")
    static let cardBackgroundUnlocked = Color(hex: "FFFCFD")
    static let cardBackgroundLocked = Color(hex: "FBFAFF")

    static let cardBorder = Color(hex: "FA9695")
    static let destructiveRed = Color(hex: "DC2626")
    static let selectionIndicatorBorder = Color(hex: "CAC4D0")
    static let selectionIndicatorFill = Color(hex: "3C7DFA")
    static let selectionIndicatorCheck = Color(hex: "FFFFFF")
    static let selectionCardBackground = Color(hex: "F6F7F8")
    static let selectionStatusRowFill = Color(hex: "FFFFFF")
    static let selectionStatusRowBorder = Color(hex: "E3E3E3")
    static let selectionDeleteFill = HomeStyle.destructiveRed
    static let selectionDeleteText = Color(hex: "FFFFFF")
    static let selectionCancelText = textPrimary
    static let selectionCountText = Color(hex: "716565")

    static let emptyStateBackground = Color(hex: "36BBBAE2")
    static let emptyStateText = textPrimary

    static let fabRed = Color(hex: "8D110E")

    static let tabSelected = Color(hex: "8D110E")
    static let tabUnselected = Color(hex: "999999")

    static let subtitle = textSecondary
}
