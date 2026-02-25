import SwiftUI

func baseSafeAreaBottom() -> CGFloat {
  #if canImport(UIKit)
    let windowScenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .sorted { lhs, rhs in
        let lhsRank = lhs.activationState == .foregroundActive ? 0 : 1
        let rhsRank = rhs.activationState == .foregroundActive ? 0 : 1
        return lhsRank < rhsRank
      }

    for scene in windowScenes {
      if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) {
        return keyWindow.safeAreaInsets.bottom
      }
      if let firstWindow = scene.windows.first {
        return firstWindow.safeAreaInsets.bottom
      }
    }
  #endif
  return 0
}
