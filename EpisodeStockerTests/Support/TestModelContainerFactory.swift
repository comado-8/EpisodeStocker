import SwiftData
@testable import EpisodeStocker

@MainActor
enum TestModelContainerFactory {
    static func makeInMemoryContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(
                for: Episode.self,
                UnlockLog.self,
                Tag.self,
                Person.self,
                Project.self,
                Emotion.self,
                Place.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to create in-memory ModelContainer: \(error)")
        }
    }
}
