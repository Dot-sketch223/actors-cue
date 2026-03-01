import SwiftUI
import SwiftData

struct RunView: View {
    let script: Script
    let scene: ScriptScene?
    let trainingWheels: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex = 0
    @State private var stumbedLineIDs: [UUID] = []
    @State private var showCueCard = false
    @State private var startDate = Date()
    @State private var sessionComplete = false
    @State private var speechService = SpeechRecognitionService()

    private var allLines: [Line] {
        let scenes = scene.map { [$0] } ?? script.scenes.sorted(by: { $0.orderIndex < $1.orderIndex })
        return scenes.flatMap { $0.lines.sorted(by: { $0.orderIndex < $1.orderIndex }) }
    }

    private var currentLine: Line? {
        guard currentIndex < allLines.count else { return nil }
        return allLines[currentIndex]
    }

    private var isUserLine: Bool {
        guard let line = currentLine else { return false }
        return line.cueType == .spoken && script.userCharacters.contains(line.character)
    }

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground).ignoresSafeArea()

            if sessionComplete {
                RunSummaryView(
                    script: script,
                    stumbedLineIDs: stumbedLineIDs,
                    allLines: allLines,
                    duration: Date().timeIntervalSince(startDate),
                    onDone: { dismiss() }
                )
            } else {
                VStack(spacing: 0) {
                    // Progress bar
                    ProgressView(value: Double(currentIndex), total: Double(max(allLines.count, 1)))
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Line counter
                    Text("\(currentIndex + 1) / \(allLines.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    Spacer()

                    // Other character's spoken line or stage direction
                    if let line = currentLine, !isUserLine {
                        if line.cueType == .direction {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Stage Direction")
                                    .font(.caption.uppercaseSmallCaps())
                                    .foregroundStyle(.secondary)
                                Text(line.text)
                                    .font(.title3)
                                    .italic()
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(line.character)
                                    .font(.caption.uppercaseSmallCaps())
                                    .foregroundStyle(.secondary)
                                Text(line.text)
                                    .font(.title3)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                        }

                        Button {
                            advance()
                        } label: {
                            Label("Continue", systemImage: "chevron.forward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal, 24)
                    }

                    Spacer()
                }

                // Cue card overlay for user lines
                if isUserLine, let line = currentLine {
                    VStack {
                        Spacer()
                        CueCardView(
                            cueingLine: currentIndex > 0 ? allLines[currentIndex - 1] : nil,
                            userLine: line,
                            trainingWheels: trainingWheels,
                            isListening: speechService.isListening,
                            onForgotIt: {
                                stumbedLineIDs.append(line.id)
                                advance()
                            },
                            onAdvance: {
                                advance()
                            }
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: isUserLine)
                }
            }
        }
        .navigationTitle(scene?.title ?? script.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(sessionComplete)
        .onAppear {
            startDate = Date()
            startSpeechIfNeeded()
        }
        .onDisappear {
            speechService.stopListening()
        }
        .onChange(of: isUserLine) { _, newValue in
            if newValue {
                startSpeechIfNeeded()
            } else {
                speechService.stopListening()
            }
        }
    }

    private func advance() {
        speechService.stopListening()
        if currentIndex + 1 >= allLines.count {
            completeSession()
        } else {
            currentIndex += 1
            if isUserLine {
                startSpeechIfNeeded()
            }
        }
    }

    private func startSpeechIfNeeded() {
        guard speechService.authStatus == .authorized else {
            Task { await speechService.requestPermissions() }
            return
        }
        speechService.onSpeechDetected = { advance() }
        try? speechService.startListening()
    }

    private func completeSession() {
        let session = RunSession(
            scriptID: script.id,
            duration: Date().timeIntervalSince(startDate),
            stumbedLineIDs: stumbedLineIDs
        )
        modelContext.insert(session)
        script.lastPracticedAt = Date()
        sessionComplete = true
    }
}
