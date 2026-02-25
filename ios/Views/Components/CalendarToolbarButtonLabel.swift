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
      .truncationMode(.tail)
      .minimumScaleFactor(0.9)
      .allowsTightening(true)
      .foregroundColor(textColor)
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(
        Capsule()
          .fill(fillColor)
      )
  }
}
