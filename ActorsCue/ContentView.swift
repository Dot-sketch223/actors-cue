import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ScriptLibraryView()
                .tabItem {
                    Label("Scripts", systemImage: "doc.text.fill")
                }

            PracticeSetupView()
                .tabItem {
                    Label("Practice", systemImage: "play.circle.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Script.self, Scene.self, Line.self, RunSession.self], inMemory: true)
}
