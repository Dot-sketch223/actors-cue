import Foundation
import SwiftData

enum CueType: String, Codable {
    case spoken
    case direction
}

@Model
final class Line {
    var id: UUID
    var character: String
    var text: String
    var stageDirection: String?
    var cueType: CueType
    var orderIndex: Int

    init(
        id: UUID = UUID(),
        character: String,
        text: String,
        stageDirection: String? = nil,
        cueType: CueType = .spoken,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.character = character
        self.text = text
        self.stageDirection = stageDirection
        self.cueType = cueType
        self.orderIndex = orderIndex
    }
}
