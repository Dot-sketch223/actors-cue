import SwiftUI
import SwiftData

@main
struct ActorsCueApp: App {
    let container: ModelContainer
    @State private var showSplash = true

    init() {
        let schema = Schema([Script.self, ScriptScene.self, Line.self, RunSession.self])
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.actorscue.app")
        )
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation(.easeOut(duration: 0.45)) {
                                    showSplash = false
                                }
                            }
                        }
                } else {
                    ContentView()
                        .transition(.opacity)
                }
            }
        }
        .modelContainer(container)
    }
}
