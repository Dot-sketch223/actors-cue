import Foundation
import SwiftData

@Model
final class Script {
    var id: UUID
    var title: String
    @Relationship(deleteRule: .cascade) var scenes: [ScriptScene]
    var userCharacters: [String]
    var createdAt: Date
    var lastPracticedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        scenes: [ScriptScene] = [],
        userCharacters: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.scenes = scenes
        self.userCharacters = userCharacters
        self.createdAt = createdAt
    }

    /// All unique character names across all scenes.
    var allCharacters: [String] {
        var seen = Set<String>()
        return scenes
            .flatMap(\.lines)
            .compactMap { line -> String? in
                guard !line.character.isEmpty, seen.insert(line.character).inserted else { return nil }
                return line.character
            }
    }
}
