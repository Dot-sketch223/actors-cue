import Foundation
import PDFKit

/// Position-aware parser for PDF-format screenplays.
///
/// Uses `PDFPage.characterBounds(at:)` to read the x/y coordinate of every
/// character, reconstructs visual lines spatially, detects column thresholds
/// from the first 10 pages, and classifies each line as a character name,
/// dialogue, parenthetical, scene heading, or action.
struct PDFScreenplayParser {

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

    // Internal so unit tests can construct synthetic input via @testable import.
    struct SpatialLine {
        let text: String
        let minX: CGFloat   // leftmost x of any non-space character on the line
    }

    struct ColumnThresholds {
        let charNameX: CGFloat   // character-name column
        let dialogueX: CGFloat   // dialogue column (≈ charNameX × 0.6)
    }

    // MARK: - Main Entry Point

    /// Returns `nil` when the document has no text layer on any page.
    func parse(document: PDFDocument) -> ParseResult? {
        var allPageLines: [[SpatialLine]] = []
        var hasText = false

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else {
                allPageLines.append([])
                continue
            }
            let lines = extractLines(from: page)
            if !lines.isEmpty { hasText = true }
            allPageLines.append(lines)
        }

        guard hasText else { return nil }
        return parse(pageLines: allPageLines)
    }

    // MARK: - Testable Core

    func parse(pageLines: [[SpatialLine]]) -> ParseResult {
        guard let thresholds = detectThresholds(from: pageLines) else {
            return ParseResult(scenes: [], detectedCharacters: [])
        }

        var scenes: [ParsedScene] = []
        var currentSceneTitle = "Scene 1"
        var currentLines: [ParsedLine] = []
        var spokenLines: [ParsedLine] = []
        var currentCharacter: String? = nil
        var dialogueParts: [String] = []

        func flushDialogue() {
            guard let char = currentCharacter, !dialogueParts.isEmpty else { return }
            let line = ParsedLine(
                character: char,
                text: dialogueParts.joined(separator: " "),
                cueType: .spoken
            )
            currentLines.append(line)
            spokenLines.append(line)
            dialogueParts = []
        }

        for spatialLine in pageLines.joined() {
            let trimmed = spatialLine.text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Strip trailing revision marks (* characters) before any classification.
            var cleaned = trimmed
            while cleaned.hasSuffix("*") {
                cleaned = String(cleaned.dropLast()).trimmingCharacters(in: .whitespaces)
            }
            guard !cleaned.isEmpty else { continue }
            guard !isPageHeader(cleaned) else { continue }

            let x = spatialLine.minX

            if x >= thresholds.charNameX - 10 {
                // Character-name zone.
                if cleaned.hasPrefix("(") {
                    // Parenthetical — flush pending dialogue and emit as direction.
                    flushDialogue()
                    if let char = currentCharacter {
                        currentLines.append(ParsedLine(character: char, text: cleaned, cueType: .direction))
                    }
                } else if cleaned == cleaned.uppercased() && cleaned.contains(where: { $0.isLetter }) {
                    // ALL-CAPS line → character name.
                    flushDialogue()
                    currentCharacter = normalizeCharacterName(cleaned)
                    dialogueParts = []   // discard any orphaned dialogue from before
                }
                // Non-caps, non-paren text in the character zone is treated as noise and ignored.

            } else if x >= thresholds.dialogueX {
                // Dialogue zone.
                dialogueParts.append(cleaned)

            } else {
                // Action zone.
                flushDialogue()
                currentCharacter = nil
                dialogueParts = []

                let upper = cleaned.uppercased()
                if isSceneHeading(upper) {
                    if !currentLines.isEmpty {
                        scenes.append(ParsedScene(title: currentSceneTitle, lines: currentLines))
                        currentLines = []
                    }
                    currentSceneTitle = cleaned
                } else {
                    currentLines.append(ParsedLine(character: "", text: cleaned, cueType: .direction))
                }
            }
        }

        flushDialogue()
        if !currentLines.isEmpty {
            scenes.append(ParsedScene(title: currentSceneTitle, lines: currentLines))
        }

        let characters = Array(Set(spokenLines.map(\.character)).filter { !$0.isEmpty }).sorted()
        return ParseResult(scenes: scenes, detectedCharacters: characters)
    }

    // MARK: - Threshold Detection

    func detectThresholds(from pageLines: [[SpatialLine]]) -> ColumnThresholds? {
        let scanCount = min(10, pageLines.count)
        var capsXs: [CGFloat] = []

        for i in 0..<scanCount {
            for line in pageLines[i] {
                let text = line.text.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty, !isPageHeader(text) else { continue }
                if text == text.uppercased() && text.contains(where: { $0.isLetter }) {
                    capsXs.append(line.minX)
                }
            }
        }

        guard capsXs.count >= 5 else { return nil }

        let sorted = capsXs.sorted()
        let median = sorted[sorted.count / 2]
        return ColumnThresholds(charNameX: median, dialogueX: median * 0.6)
    }

    // MARK: - PDFKit Extraction

    private func extractLines(from page: PDFPage) -> [SpatialLine] {
        guard let pageString = page.string, !pageString.isEmpty else { return [] }
        let nsString = pageString as NSString
        let length = nsString.length

        struct CharPoint { let char: Character; let x: CGFloat; let y: CGFloat }
        var points: [CharPoint] = []
        var lastY: CGFloat = 0
        var lastMaxX: CGFloat = 0

        for i in 0..<length {
            let charStr = nsString.substring(with: NSRange(location: i, length: 1))
            guard let ch = charStr.first else { continue }
            guard ch != "\n", ch != "\r" else {
                lastMaxX = 0
                continue
            }

            let bounds = page.characterBounds(at: i)
            if bounds.width > 0.5 && bounds.height > 0.5 {
                lastY = bounds.midY
                lastMaxX = bounds.maxX
                points.append(CharPoint(char: ch, x: bounds.minX, y: lastY))
            } else if ch == " " && lastY > 0 {
                // Spaces often have zero-width bounds; position them after the previous glyph.
                points.append(CharPoint(char: ch, x: lastMaxX + 0.5, y: lastY))
                lastMaxX += 4   // approximate space advance
            }
        }

        // Sort top-to-bottom (PDF y-axis: 0 at bottom, so higher y = higher on page).
        let sorted = points.sorted { $0.y > $1.y }

        // Group characters into visual lines by y-coordinate (±3 pt tolerance).
        struct LineGroup { var y: CGFloat; var chars: [(x: CGFloat, char: Character)] }
        var lineGroups: [LineGroup] = []
        for pt in sorted {
            if !lineGroups.isEmpty && abs(lineGroups[lineGroups.count - 1].y - pt.y) <= 3 {
                lineGroups[lineGroups.count - 1].chars.append((pt.x, pt.char))
            } else {
                lineGroups.append(LineGroup(y: pt.y, chars: [(pt.x, pt.char)]))
            }
        }

        return lineGroups.compactMap { group in
            let sortedChars = group.chars.sorted { $0.x < $1.x }
            let text = String(sortedChars.map { $0.char })
            // minX is the leftmost non-space character (used for column classification).
            let minX = sortedChars.filter { $0.char != " " }.min(by: { $0.x < $1.x })?.x
            guard let minX else { return nil }
            return SpatialLine(text: text, minX: minX)
        }
    }

    // MARK: - Helpers

    func normalizeCharacterName(_ name: String) -> String {
        let patterns = [
            #"\s*\(V\.O\./O\.S\.\)"#,
            #"\s*\(CONT'D\.?\)"#,
            #"\s*\(O\.S\.\)"#,
            #"\s*\(V\.O\.\)"#,
            #"\s*\(O\.C\.\)"#,
        ]
        var result = name
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    func isPageHeader(_ text: String) -> Bool {
        // Revision line containing "Rev. (MM/DD/YYYY)".
        if text.range(of: #"Rev\. \(\d{2}/\d{2}/\d{4}\)"#, options: .regularExpression) != nil {
            return true
        }
        // Bare page number such as "5." or "12.".
        if text.range(of: #"^\d+\.$"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private func isSceneHeading(_ upper: String) -> Bool {
        // Strip leading scene numbers such as "1." "2A." "12C." before matching.
        let stripped = upper.replacingOccurrences(
            of: #"^\d+[A-Z]?\.\s*"#, with: "", options: .regularExpression)
        return stripped.hasPrefix("INT.") || stripped.hasPrefix("EXT.") ||
               stripped.hasPrefix("INT/EXT") || stripped.hasPrefix("I/E")
    }
}
