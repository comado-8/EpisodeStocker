import SwiftUI

enum AppRoute: Hashable {
    case newEpisode
    case episodeDetail(UUID)
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [AppRoute] = []

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        _ = path.popLast()
    }
}
