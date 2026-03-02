import SwiftUI
import SwiftData

@main
struct ActorsCueApp: App {
    let container: ModelContainer
    @State private var showSplash = true

    init() {
        let schema = Schema([Script.self, ScriptScene.self, Line.self, RunSession.self])
        container = Self.makeContainer(schema: schema)
    }

    private static func makeContainer(schema: Schema) -> ModelContainer {
        let cloudConfig = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.actorscue.app")
        )
        if let c = try? ModelContainer(for: schema, configurations: cloudConfig) {
            return c
        }

        // CloudKit unavailable — fall back to a strictly local store.
        // Must pass cloudKitDatabase: .none explicitly; the default (.automatic)
        // re-detects the CloudKit entitlement and fails the same way.
        let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        if let c = try? ModelContainer(for: schema, configurations: localConfig) {
            return c
        }

        // Local store is also unreadable (e.g. incompatible store left over from
        // a previous CloudKit configuration). Delete the on-disk files and retry.
        // This only runs when the store is already unreadable, so no good data is lost.
        let storeURL = localConfig.url
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            try? fm.removeItem(atPath: storeURL.path + suffix)
        }
        return try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        )
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
