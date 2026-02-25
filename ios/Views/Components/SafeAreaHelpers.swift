import SwiftUI

func baseSafeAreaBottom() -> CGFloat {
  #if canImport(UIKit)
    let windowScene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first
    if let window = windowScene?.windows.first(where: { $0.isKeyWindow }) {
      return window.safeAreaInsets.bottom
    }
  #endif
  return 0
}

