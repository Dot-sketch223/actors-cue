import SwiftUI
import SwiftData

@main
struct ActorsCueApp: App {
    let container: ModelContainer
    @State private var showSplash = true

    init() {
        let schema = Schema([Script.self, ScriptScene.self, Line.self, RunSession.self])
        let cloudConfig = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.actorscue.app")
        )
        if let cloudContainer = try? ModelContainer(for: schema, configurations: cloudConfig) {
            container = cloudContainer
        } else {
            // CloudKit unavailable (container not provisioned, no entitlement, or simulator).
            // Fall back to a local-only store so the app remains functional.
            let localConfig = ModelConfiguration(schema: schema)
            container = try! ModelContainer(for: schema, configurations: localConfig)
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
