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
                    // ALL-CAPS line → character name (if long enough after normalisation).
                    let normalized = normalizeCharacterName(cleaned)
                    if normalized.filter({ $0.isLetter }).count >= 2 {
                        flushDialogue()
                        currentCharacter = normalized
                        dialogueParts = []   // discard any orphaned dialogue from before
                    }
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

        // Deduplicate: discard any name that is a strict prefix of a longer name
        // (these are reconstruction fragments, e.g. "PA" when "PAUL" also exists).
        var chars = Array(Set(spokenLines.map(\.character)).filter { !$0.isEmpty })
        chars = chars.filter { name in
            !chars.contains { other in other.count > name.count && other.hasPrefix(name) }
        }
        return ParseResult(scenes: scenes, detectedCharacters: chars.sorted())
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

        // Split page.string by newlines. Each newline-delimited segment is a text object
        // from the PDF content stream whose characters are already in correct reading order.
        // We use characterBounds only to find each segment's visual y-position (for
        // top-to-bottom ordering) and its leftmost x (for column classification).
        // We do NOT re-sort individual characters by x — that caused garbled output
        // when character bounding boxes were clustered at identical x values.
        struct Segment { let text: String; let minX: CGFloat; let y: CGFloat }
        var segments: [Segment] = []
        var segStart = 0

        func processRange(_ start: Int, _ end: Int) {
            guard end > start else { return }
            let raw = nsString.substring(with: NSRange(location: start, length: end - start))
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }

            var firstY: CGFloat = -1
            var minX: CGFloat = .greatestFiniteMagnitude
            for j in start..<end {
                let b = page.characterBounds(at: j)
                guard b.width > 0.5 && b.height > 0.5 else { continue }
                if firstY < 0 { firstY = b.midY }
                minX = min(minX, b.minX)
            }
            guard firstY > 0, minX < .greatestFiniteMagnitude else { return }
            segments.append(Segment(text: trimmed, minX: minX, y: firstY))
        }

        for i in 0..<length {
            let ch = nsString.character(at: i)
            if ch == 10 || ch == 13 {   // \n or \r
                processRange(segStart, i)
                segStart = i + 1
            }
        }
        processRange(segStart, length)

        // Sort top-to-bottom: higher y = higher on page in PDF coordinates.
        segments.sort { $0.y > $1.y }
        return segments.map { SpatialLine(text: $0.text, minX: $0.minX) }
    }

    // MARK: - Helpers

    func normalizeCharacterName(_ name: String) -> String {
        let patterns = [
            #"\s*\(V\.O\./O\.S\.\)"#,
            #"\s*\(CONT'D\.?\)"#,
            #"\s*\(O\.S\.\)"#,
            #"\s*\(V\.O\.\)"#,
            #"\s*\(O\.C\.\)"#,
            #"\s*\([^)]*$"#,    // unclosed parenthetical (closing ) split to another segment)
        ]
        var result = name
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        result = result.trimmingCharacters(in: .whitespaces)
        // Strip leading non-letter characters (stray periods, asterisks, colons that
        // ended up spatially grouped with the character name from an adjacent PDF element).
        if let firstLetter = result.firstIndex(where: { $0.isLetter }) {
            result = String(result[firstLetter...])
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
