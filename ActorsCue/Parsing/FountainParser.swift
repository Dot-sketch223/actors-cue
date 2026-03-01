import Foundation

/// Parses Fountain-format screenwriting files (.fountain).
/// Fountain spec: https://fountain.io/syntax
struct FountainParser {

    struct ParseResult {
        let scenes: [ParsedScene]
        let detectedCharacters: [String]
    }

    struct ParsedScene {
        let title: String
        let lines: [ParsedLine]
    }

    struct ParsedLine {
        let character: String
        let text: String
        let cueType: CueType
    }

    func parse(text: String) -> ParseResult {
        let rawLines = text.components(separatedBy: .newlines)
        var scenes: [ParsedScene] = []
        var currentSceneTitle = "Scene 1"
        var currentLines: [ParsedLine] = []
        var spokenLines: [ParsedLine] = []  // used only for detectedCharacters

        var i = 0
        while i < rawLines.count {
            let raw = rawLines[i]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            // Scene heading: INT./EXT. or a line forced with a period prefix
            if isSceneHeading(trimmed) {
                if !currentLines.isEmpty {
                    scenes.append(ParsedScene(title: currentSceneTitle, lines: currentLines))
                    currentLines = []
                }
                currentSceneTitle = trimmed.hasPrefix(".") ? String(trimmed.dropFirst()) : trimmed
                i += 1
                continue
            }

            // Skip blank lines
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Character cue: ALL CAPS, may end with ^ for dual-dialogue, preceded by blank line
            if isCharacterCue(trimmed, previousLine: i > 0 ? rawLines[i - 1] : "") {
                let character = trimmed
                    .replacingOccurrences(of: "^", with: "")
                    .trimmingCharacters(in: .whitespaces)

                i += 1
                var dialogueParts: [String] = []

                while i < rawLines.count {
                    let next = rawLines[i].trimmingCharacters(in: .whitespaces)
                    if next.isEmpty { break }

                    if next.hasPrefix("(") && next.hasSuffix(")") {
                        // Flush any accumulated dialogue before emitting the parenthetical
                        if !dialogueParts.isEmpty {
                            let spoken = ParsedLine(character: character, text: dialogueParts.joined(separator: " "), cueType: .spoken)
                            currentLines.append(spoken)
                            spokenLines.append(spoken)
                            dialogueParts = []
                        }
                        currentLines.append(ParsedLine(character: character, text: next, cueType: .direction))
                        i += 1
                        continue
                    }

                    dialogueParts.append(next)
                    i += 1
                }

                if !dialogueParts.isEmpty {
                    let spoken = ParsedLine(character: character, text: dialogueParts.joined(separator: " "), cueType: .spoken)
                    currentLines.append(spoken)
                    spokenLines.append(spoken)
                }
                continue
            }

            // Action line — a stage direction outside any dialogue block
            currentLines.append(ParsedLine(character: "", text: trimmed, cueType: .direction))
            i += 1
        }

        if !currentLines.isEmpty {
            scenes.append(ParsedScene(title: currentSceneTitle, lines: currentLines))
        }

        if scenes.isEmpty && !spokenLines.isEmpty {
            scenes = [ParsedScene(title: "Scene 1", lines: spokenLines)]
        }

        let characters = Array(Set(spokenLines.map(\.character)).filter { !$0.isEmpty }).sorted()
        return ParseResult(scenes: scenes, detectedCharacters: characters)
    }

    // MARK: - Helpers

    private func isSceneHeading(_ line: String) -> Bool {
        if line.hasPrefix(".") && !line.hasPrefix("..") { return true }
        let upper = line.uppercased()
        return upper.hasPrefix("INT.") || upper.hasPrefix("EXT.") ||
               upper.hasPrefix("INT/EXT") || upper.hasPrefix("I/E")
    }

    private func isCharacterCue(_ line: String, previousLine: String) -> Bool {
        guard !line.isEmpty else { return false }
        // Must be ALL CAPS (with optional trailing ^ or parenthetical)
        let base = line
            .replacingOccurrences(of: "^", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard base == base.uppercased(), base.contains(where: { $0.isLetter }) else { return false }
        // Preceded by an empty line (per Fountain spec)
        return previousLine.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
