import SwiftUI

enum AppRoute: Hashable {
    case newEpisode
    case episodeDetail(UUID)
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var hasUnsavedEpisodeDetailChanges = false
    @Published var pendingRootTabSwitch: RootTab?
    @Published var committedRootTabSwitch: RootTab?

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        _ = path.popLast()
    }

    func requestRootTabSwitch(_ tab: RootTab) {
        pendingRootTabSwitch = tab
    }

    func cancelRootTabSwitchRequest() {
        pendingRootTabSwitch = nil
    }

    func commitRootTabSwitch(_ tab: RootTab) {
        pendingRootTabSwitch = nil
        committedRootTabSwitch = tab
    }

    func consumeCommittedRootTabSwitch() {
        committedRootTabSwitch = nil
    }
}
