import SwiftUI
import SwiftData

struct ScriptLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Script.createdAt, order: .reverse) private var scripts: [Script]

    @State private var showingImport = false

    var body: some View {
        NavigationStack {
            Group {
                if scripts.isEmpty {
                    ContentUnavailableView(
                        "No Scripts Yet",
                        systemImage: "doc.text",
                        description: Text("Tap the import button to add your first script.")
                    )
                } else {
                    List {
                        ForEach(scripts) { script in
                            NavigationLink {
                                PracticeSetupView(script: script)
                            } label: {
                                ScriptCard(script: script)
                            }
                        }
                        .onDelete(perform: deleteScripts)
                    }
                }
            }
            .navigationTitle("My Scripts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingImport = true
                    } label: {
                        Label("Import", systemImage: "plus")
                    }
                }
                if !scripts.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingImport) {
                ImportView()
            }
        }
    }

    private func deleteScripts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(scripts[index])
        }
    }
}

#Preview {
    ScriptLibraryView()
        .modelContainer(for: [Script.self, ScriptScene.self, Line.self, RunSession.self], inMemory: true)
}
