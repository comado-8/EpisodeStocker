import SwiftUI

struct CalendarToolbarButtonLabel: View {
  let title: String
  let font: Font
  let fillColor: Color
  let textColor: Color

  var body: some View {
    Text(title)
      .font(font)
      .lineLimit(1)
      .fixedSize(horizontal: true, vertical: false)
      .foregroundColor(textColor)
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(
        Capsule()
          .fill(fillColor)
      )
  }
}
