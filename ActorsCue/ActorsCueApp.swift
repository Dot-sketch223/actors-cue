import SwiftUI
import SwiftData

@main
struct ActorsCueApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Script.self, Scene.self, Line.self, RunSession.self])
    }
}
