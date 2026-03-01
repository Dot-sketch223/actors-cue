import SwiftUI
import SwiftData

struct PracticeSetupView: View {
    var script: Script?

    @Query(sort: \Script.lastPracticedAt, order: .reverse) private var scripts: [Script]
    @State private var selectedScene: ScriptScene?
    @State private var trainingWheels = true
    @State private var navigateToRun = false
    @State private var showingRolePicker = false

    private var activeScript: Script? { script ?? scripts.first }

    var body: some View {
        NavigationStack {
            if let script = activeScript {
                Form {
                    Section("Script") {
                        Text(script.title)
                            .font(.headline)
                        Button {
                            showingRolePicker = true
                        } label: {
                            if script.userCharacters.isEmpty {
                                Label("Assign your role", systemImage: "person.badge.plus")
                            } else {
                                HStack {
                                    Text("Playing: \(script.userCharacters.joined(separator: ", "))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }

                    Section("Scene") {
                        Picker("Scene", selection: $selectedScene) {
                            Text("Full Script").tag(Optional<ScriptScene>.none)
                            ForEach(script.scenes.sorted(by: { $0.orderIndex < $1.orderIndex })) { scene in
                                Text(scene.title).tag(Optional(scene))
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }

                    Section {
                        Toggle("Training Wheels", isOn: $trainingWheels)
                    } footer: {
                        Text("When on, your lines are shown on the cue card. Turn off to test from memory.")
                    }

                    Section {
                        Button {
                            navigateToRun = true
                        } label: {
                            Label("Start Run", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(script.userCharacters.isEmpty)
                    }

                }
                .navigationTitle("Practice Setup")
                .sheet(isPresented: $showingRolePicker) {
                    AssignRoleView(script: script)
                }
                .navigationDestination(isPresented: $navigateToRun) {
                    RunView(
                        script: script,
                        scene: selectedScene,
                        trainingWheels: trainingWheels
                    )
                }
            } else {
                ContentUnavailableView(
                    "No Script Selected",
                    systemImage: "play.slash",
                    description: Text("Import a script from the Scripts tab to get started.")
                )
                .navigationTitle("Practice")
            }
        }
    }
}

#Preview {
    PracticeSetupView()
        .modelContainer(for: [Script.self, ScriptScene.self, Line.self], inMemory: true)
}
