import SwiftUI

struct ContentView: View {
    @State private var sharedFileURL: URL?
    @State private var showExternalImport = false
    @Environment(\.modelContext) private var modelContext

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
        .onOpenURL { url in
            sharedFileURL = url
            showExternalImport = true
        }
        .sheet(isPresented: $showExternalImport) {
            ImportView(initialURL: sharedFileURL)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Script.self, ScriptScene.self, Line.self, RunSession.self], inMemory: true)
}
