import SwiftUI
import SwiftData

struct AssignRoleView: View {
    let script: Script

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRoles: Set<String>

    init(script: Script) {
        self.script = script
        _selectedRoles = State(initialValue: Set(script.userCharacters))
    }

    var body: some View {
        NavigationStack {
            Group {
                if script.allCharacters.isEmpty {
                    ContentUnavailableView(
                        "No Characters",
                        systemImage: "person.slash",
                        description: Text("This script has no detected characters.")
                    )
                } else {
                    List(script.allCharacters, id: \.self) { character in
                        Button {
                            toggleRole(character)
                        } label: {
                            HStack {
                                Text(character)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedRoles.contains(character) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Assign Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        script.userCharacters = Array(selectedRoles).sorted()
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func toggleRole(_ character: String) {
        if selectedRoles.contains(character) {
            selectedRoles.remove(character)
        } else {
            selectedRoles.insert(character)
        }
    }
}
