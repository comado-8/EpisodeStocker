import SwiftUI

struct FlowLayout: Layout {
  let spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .greatestFiniteMagnitude
    var currentX: CGFloat = 0
    var totalHeight: CGFloat = 0
    var lineHeight: CGFloat = 0
    var maxLineWidth: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if currentX + size.width > maxWidth, currentX > 0 {
        totalHeight += lineHeight + spacing
        maxLineWidth = max(maxLineWidth, currentX - spacing)
        currentX = 0
        lineHeight = 0
      }
      currentX += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }

    totalHeight += lineHeight
    maxLineWidth = max(maxLineWidth, currentX - spacing)

    let width = proposal.width ?? maxLineWidth
    return CGSize(width: width, height: totalHeight)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    var currentX = bounds.minX
    var currentY = bounds.minY
    var lineHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if currentX + size.width > bounds.maxX, currentX > bounds.minX {
        currentX = bounds.minX
        currentY += lineHeight + spacing
        lineHeight = 0
      }
      subview.place(
        at: CGPoint(x: currentX, y: currentY),
        proposal: ProposedViewSize(width: size.width, height: size.height)
      )
      currentX += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }
  }
}
