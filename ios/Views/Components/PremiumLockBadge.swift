import SwiftUI

struct PremiumLockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: HomeStyle.premiumLockBadgeIconSize, weight: .bold))
            .foregroundColor(.white)
            .accessibilityHidden(true)
            .padding(HomeStyle.premiumLockBadgePadding)
            .background(
                Circle()
                    .fill(HomeStyle.fabRed)
            )
    }
}
