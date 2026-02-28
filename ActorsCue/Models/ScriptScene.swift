import Foundation
import SwiftData

@Model
final class ScriptScene {
    var id: UUID
    var title: String
    var orderIndex: Int
    @Relationship(deleteRule: .cascade) var lines: [Line]

    init(
        id: UUID = UUID(),
        title: String,
        orderIndex: Int = 0,
        lines: [Line] = []
    ) {
        self.id = id
        self.title = title
        self.orderIndex = orderIndex
        self.lines = lines
    }
}
