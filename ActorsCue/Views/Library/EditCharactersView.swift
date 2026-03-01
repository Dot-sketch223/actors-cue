import SwiftUI
import SwiftData

struct EditCharactersView: View {
    let script: Script

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [CharacterEntry]

    init(script: Script) {
        self.script = script
        _entries = State(initialValue: script.allCharacters.map {
            CharacterEntry(original: $0, pending: $0)
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($entries) { $entry in
                        TextField("Character name", text: $entry.pending)
                    }
                } header: {
                    Text("Characters")
                } footer: {
                    Text("Edit a name to rename it across all lines. Type an existing name to merge the two characters.")
                }
            }
            .navigationTitle("Edit Characters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        applyRenames()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func applyRenames() {
        for entry in entries {
            let newName = entry.pending.trimmingCharacters(in: .whitespaces)
            guard !newName.isEmpty, newName != entry.original else { continue }
            script.renameCharacter(from: entry.original, to: newName)
        }
        try? modelContext.save()
    }
}

private struct CharacterEntry: Identifiable {
    let id = UUID()
    let original: String
    var pending: String
}
