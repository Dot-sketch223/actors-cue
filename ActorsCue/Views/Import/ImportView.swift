import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let initialURL: URL?

    init(initialURL: URL? = nil) {
        self.initialURL = initialURL
    }

    @State private var showingFilePicker = false
    @State private var parseError: String?
    @State private var parsedResult: ImportParseResult?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Import a Script")
                        .font(.title2.bold())
                    Text("Choose a plain text (.txt), Fountain (.fountain), or PDF file from your Files app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let error = parseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Button {
                    showingFilePicker = true
                } label: {
                    Label("Choose File", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Import Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [
                    .plainText,
                    .pdf,
                    UTType("com.actorscue.fountain") ?? UTType(filenameExtension: "fountain") ?? .text
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .onAppear {
                if let url = initialURL {
                    let secured = url.startAccessingSecurityScopedResource()
                    processURL(url)
                    if secured { url.stopAccessingSecurityScopedResource() }
                }
            }
            .navigationDestination(item: $parsedResult) { result in
                CharacterReviewView(parseResult: result, onSave: { script in
                    modelContext.insert(script)
                    dismiss()
                })
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        parseError = nil
        switch result {
        case .failure(let error):
            parseError = "Could not open file: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                parseError = "Permission denied for selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            processURL(url)
        }
    }

    private func processURL(_ url: URL) {
        parseError = nil
        let ext = url.pathExtension.lowercased()
        let fileName = url.deletingPathExtension().lastPathComponent

        if ext == "pdf" {
            processPDF(url: url, fileName: fileName)
            return
        }

        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            parseError = "Could not read file: \(error.localizedDescription)"
            return
        }

        let format: ScriptFormat = (ext == "fountain" || looksLikeFountain(text)) ? .fountain : .plainText
        applyParser(text: text, fileName: fileName, format: format)
    }

    // MARK: - PDF Path

    private func processPDF(url: URL, fileName: String) {
        guard let document = PDFDocument(url: url) else {
            parseError = "Could not open PDF."
            return
        }

        // Try position-aware screenplay parser. Returns nil when there is no text layer.
        guard let pdfResult = PDFScreenplayParser().parse(document: document) else {
            parseError = "This PDF has no text layer. Please use a PDF with selectable text."
            return
        }

        if !pdfResult.detectedCharacters.isEmpty {
            // Successfully parsed as a structured screenplay.
            parsedResult = ImportParseResult(
                fileName: fileName,
                format: .fountain,
                scenes: pdfResult.scenes.map { s in
                    ParsedSceneData(title: s.title, lines: s.lines.map {
                        ParsedLineData(character: $0.character, text: $0.text, cueType: $0.cueType)
                    })
                },
                detectedCharacters: pdfResult.detectedCharacters
            )
            return
        }

        // Fallback: the PDF has a text layer but does not look like a formatted screenplay
        // (e.g. a plain-text or Fountain script saved as PDF). Extract text and try again.
        let text = document.string ?? ""
        let format: ScriptFormat = looksLikeFountain(text) ? .fountain : .plainText
        applyParser(text: text, fileName: fileName, format: format)
    }

    // MARK: - Text-based Parsing

    private func applyParser(text: String, fileName: String, format: ScriptFormat) {
        if format == .fountain {
            let result = FountainParser().parse(text: text)
            parsedResult = ImportParseResult(
                fileName: fileName,
                format: .fountain,
                scenes: result.scenes.map { s in
                    ParsedSceneData(title: s.title, lines: s.lines.map {
                        ParsedLineData(character: $0.character, text: $0.text, cueType: $0.cueType)
                    })
                },
                detectedCharacters: result.detectedCharacters
            )
        } else {
            let result = PlainTextParser().parse(text: text)
            parsedResult = ImportParseResult(
                fileName: fileName,
                format: .plainText,
                scenes: result.scenes.map { s in
                    ParsedSceneData(title: s.title, lines: s.lines.map {
                        ParsedLineData(character: $0.character, text: $0.text, cueType: $0.cueType)
                    })
                },
                detectedCharacters: result.detectedCharacters
            )
        }

        if parsedResult?.detectedCharacters.isEmpty == true {
            parseError = "No characters detected. Make sure character names are in ALL CAPS."
            parsedResult = nil
        }
    }

    /// Returns true if the text looks like a Fountain screenplay
    /// (contains standard scene-heading prefixes).
    private func looksLikeFountain(_ text: String) -> Bool {
        let upper = text.uppercased()
        return upper.contains("\nINT.") || upper.contains("\nEXT.")
            || upper.contains("\nINT/EXT") || upper.contains("\nI/E.")
    }
}

// MARK: - Data Transfer Types

enum ScriptFormat { case plainText, fountain }

struct ImportParseResult: Identifiable, Hashable {
    let id = UUID()
    let fileName: String
    let format: ScriptFormat
    let scenes: [ParsedSceneData]
    let detectedCharacters: [String]

    static func == (lhs: ImportParseResult, rhs: ImportParseResult) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ParsedSceneData {
    let title: String
    let lines: [ParsedLineData]
}

struct ParsedLineData {
    let character: String
    let text: String
    let cueType: CueType
}
