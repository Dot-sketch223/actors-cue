import SwiftUI

struct CharacterReviewView: View {
    let parseResult: ImportParseResult
    let onSave: (Script) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var characterNames: [String]
    @State private var selectedRoles: Set<String> = []
    @State private var scriptTitle: String

    private var allLines: [ParsedLineData] { parseResult.scenes.flatMap(\.lines) }
    private let previewLimit = 30

    init(parseResult: ImportParseResult, onSave: @escaping (Script) -> Void) {
        self.parseResult = parseResult
        self.onSave = onSave
        _characterNames = State(initialValue: parseResult.detectedCharacters)
        _scriptTitle = State(initialValue: parseResult.fileName)
    }

    var body: some View {
        Form {
            Section("Script Title") {
                TextField("Title", text: $scriptTitle)
            }

            Section {
                ForEach($characterNames, id: \.self) { $name in
                    HStack {
                        TextField("Character name", text: $name)
                        Spacer()
                        Button {
                            toggleRole(name)
                        } label: {
                            Image(systemName: selectedRoles.contains(name)
                                  ? "person.fill"
                                  : "person.badge.plus")
                                .foregroundStyle(selectedRoles.contains(name)
                                                 ? Color.accentColor : Color.secondary)
                                .imageScale(.large)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Characters")
            } footer: {
                Text("Tap \(Image(systemName: "person.badge.plus")) to mark a character as your role. You can play multiple parts.")
            }

            Section("Your Role(s)") {
                if selectedRoles.isEmpty {
                    Text("No role selected — tap characters above")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(selectedRoles).sorted(), id: \.self) { role in
                        Label(role, systemImage: "person.fill")
                    }
                }
            }

            Section {
                ForEach(Array(allLines.prefix(previewLimit).enumerated()), id: \.offset) { _, line in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.character)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(line.text)
                            .font(.caption)
                    }
                    .padding(.vertical, 2)
                }
                if allLines.count > previewLimit {
                    Text("… and \(allLines.count - previewLimit) more lines")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } header: {
                Text("Script Preview")
            } footer: {
                Text("\(allLines.count) lines total")
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("Review Characters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save Script") {
                    saveScript()
                }
                .disabled(scriptTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                .fontWeight(.semibold)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            }
        }
    }

    private func toggleRole(_ name: String) {
        if selectedRoles.contains(name) {
            selectedRoles.remove(name)
        } else {
            selectedRoles.insert(name)
        }
    }

    private func saveScript() {
        let scenes: [ScriptScene] = parseResult.scenes.enumerated().map { (sceneIdx, sceneData) in
            let lines: [Line] = sceneData.lines.enumerated().map { (lineIdx, lineData) in
                Line(
                    character: lineData.character,
                    text: lineData.text,
                    cueType: lineData.cueType,
                    orderIndex: lineIdx
                )
            }
            return ScriptScene(title: sceneData.title, orderIndex: sceneIdx, lines: lines)
        }

        let script = Script(
            title: scriptTitle.trimmingCharacters(in: .whitespaces),
            scenes: scenes,
            userCharacters: Array(selectedRoles).sorted()
        )

        onSave(script)
    }
}
