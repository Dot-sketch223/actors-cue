import Foundation
import SwiftData

@Model
final class RunSession {
    var id: UUID
    var scriptID: UUID
    var date: Date
    var duration: TimeInterval
    var stumbedLineIDs: [UUID]

    init(
        id: UUID = UUID(),
        scriptID: UUID,
        date: Date = Date(),
        duration: TimeInterval = 0,
        stumbedLineIDs: [UUID] = []
    ) {
        self.id = id
        self.scriptID = scriptID
        self.date = date
        self.duration = duration
        self.stumbedLineIDs = stumbedLineIDs
    }

    var stumbedCount: Int { stumbedLineIDs.count }
}
