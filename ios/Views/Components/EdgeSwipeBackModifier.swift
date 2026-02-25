import SwiftUI

struct EdgeSwipeBackModifier: ViewModifier {
  let isEnabled: Bool
  let edgeWidth: CGFloat
  let minimumDistance: CGFloat
  let maximumVerticalDrift: CGFloat
  let onBack: () -> Void

  func body(content: Content) -> some View {
    content
      .simultaneousGesture(
        DragGesture(minimumDistance: minimumDistance, coordinateSpace: .local)
          .onEnded { value in
            guard isEnabled else { return }
            let dx = value.translation.width
            let dy = value.translation.height
            guard value.startLocation.x <= edgeWidth else { return }
            guard dx > minimumDistance else { return }
            guard abs(dx) > abs(dy) else { return }
            guard abs(dy) <= maximumVerticalDrift else { return }
            onBack()
          }
      )
  }
}

extension View {
  func edgeSwipeBack(
    isEnabled: Bool = true,
    edgeWidth: CGFloat = 28,
    minimumDistance: CGFloat = 64,
    maximumVerticalDrift: CGFloat = 48,
    onBack: @escaping () -> Void
  ) -> some View {
    modifier(
      EdgeSwipeBackModifier(
        isEnabled: isEnabled,
        edgeWidth: edgeWidth,
        minimumDistance: minimumDistance,
        maximumVerticalDrift: maximumVerticalDrift,
        onBack: onBack
      )
    )
  }
}
