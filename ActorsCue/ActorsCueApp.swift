import SwiftUI
import SwiftData

@main
struct ActorsCueApp: App {
    @State private var showSplash = true

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
        .modelContainer(for: [Script.self, ScriptScene.self, Line.self, RunSession.self])
    }
}
