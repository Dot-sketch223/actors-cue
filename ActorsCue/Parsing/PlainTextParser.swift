import Foundation

/// Parses plain-text scripts in two common formats:
/// 1. `CHARACTER NAME: Dialogue text` (inline colon)
/// 2. `CHARACTER NAME\nDialogue text` (character on its own line, ALL CAPS)
struct PlainTextParser {

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
        var parsedLines: [ParsedLine] = []
        var i = 0

        while i < rawLines.count {
            let raw = rawLines[i].trimmingCharacters(in: .whitespaces)

            // Stage direction: surrounded by parentheses
            if raw.hasPrefix("(") && raw.hasSuffix(")") {
                i += 1
                continue
            }

            // Format 1: "CHARACTER: text" — character is ALL CAPS before colon
            if let colonRange = raw.range(of: ": ") {
                let potentialChar = String(raw[raw.startIndex ..< colonRange.lowerBound])
                if isCharacterName(potentialChar) {
                    let dialoguePart = String(raw[colonRange.upperBound...])
                    parsedLines.append(ParsedLine(character: potentialChar, text: dialoguePart, cueType: .spoken))
                    i += 1
                    continue
                }
            }

            // Format 2: standalone ALL CAPS line followed by dialogue on next line(s)
            if isCharacterName(raw) && i + 1 < rawLines.count {
                let character = raw
                var dialogueParts: [String] = []
                i += 1
                while i < rawLines.count {
                    let next = rawLines[i].trimmingCharacters(in: .whitespaces)
                    if next.isEmpty || isCharacterName(next) { break }
                    dialogueParts.append(next)
                    i += 1
                }
                if !dialogueParts.isEmpty {
                    parsedLines.append(ParsedLine(
                        character: character,
                        text: dialogueParts.joined(separator: " "),
                        cueType: .spoken
                    ))
                }
                continue
            }

            i += 1
        }

        let characters = Array(Set(parsedLines.map(\.character))).sorted()
        let scene = ParsedScene(title: "Scene 1", lines: parsedLines)
        return ParseResult(scenes: [scene], detectedCharacters: characters)
    }

    // MARK: - Helpers

    /// A character name is all uppercase letters (and spaces/periods), at least 2 chars, no digits.
    private func isCharacterName(_ s: String) -> Bool {
        guard s.count >= 2 else { return false }
        let upper = s.uppercased()
        guard s == upper else { return false }
        // Must contain at least one letter
        guard s.contains(where: { $0.isLetter }) else { return false }
        // Must not contain lowercase (already checked) or digits
        return !s.contains(where: { $0.isNumber })
    }
}
