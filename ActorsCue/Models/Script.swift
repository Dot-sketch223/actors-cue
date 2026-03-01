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

    /// All unique character names across all scenes, in order of first appearance.
    var allCharacters: [String] {
        var seen = Set<String>()
        return scenes
            .flatMap(\.lines)
            .compactMap { line -> String? in
                guard !line.character.isEmpty, seen.insert(line.character).inserted else { return nil }
                return line.character
            }
    }

    /// Renames every line whose character matches `oldName` to `newName`,
    /// and updates `userCharacters` accordingly.
    /// If `newName` already exists the two characters are merged.
    func renameCharacter(from oldName: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != oldName else { return }

        for scene in scenes {
            for line in scene.lines where line.character == oldName {
                line.character = trimmed
            }
        }

        if let idx = userCharacters.firstIndex(of: oldName) {
            if userCharacters.contains(trimmed) {
                userCharacters.remove(at: idx)
            } else {
                userCharacters[idx] = trimmed
            }
        }
    }
}
