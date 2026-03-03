import XCTest
@testable import ActorsCue

// Convenience alias so tests don't need the full qualified name.
fileprivate typealias Parser = PDFScreenplayParser
fileprivate typealias SL = PDFScreenplayParser.SpatialLine
fileprivate typealias Thresholds = PDFScreenplayParser.ColumnThresholds

// MARK: - Helpers

/// Build a minimal [[SpatialLine]] where ALL-CAPS lines land at `charNameX`
/// and there are enough of them for threshold detection to succeed.
///
/// Layout (charNameX = 200):
///   action zone:   x = 70   (< dialogueX 120)
///   dialogue zone: x = 130  (>= 120, < 190)
///   char-name zone: x = 200 (>= charNameX - 10 = 190)
private let stdThresholds = Thresholds(charNameX: 200, dialogueX: 120)

/// Create a single-page [[SpatialLine]] array whose ALL-CAPS lines are at
/// `charNameX = 200` so that `detectThresholds` returns charNameX = 200.
/// Includes 6 ALL-CAPS lines to satisfy the minimum-5 requirement.
private func makePage(_ lines: [SL]) -> [[SL]] { [lines] }

private func charLine(_ name: String) -> SL { SL(text: name, minX: 200) }
private func dialogueLine(_ text: String) -> SL { SL(text: text, minX: 130) }
private func actionLine(_ text: String) -> SL { SL(text: text, minX: 70) }
private func parentheticalLine(_ text: String) -> SL { SL(text: "(\(text))", minX: 200) }

/// A page with enough ALL-CAPS lines at x=200 to ensure threshold detection works,
/// plus the caller-supplied content lines.
private func pageWithThresholdLines(then content: [SL]) -> [[SL]] {
    // Six padding character-name lines so detectThresholds can find charNameX = 200.
    let padding: [SL] = [
        charLine("ALPHA"), charLine("BETA"), charLine("GAMMA"),
        charLine("DELTA"), charLine("EPSILON"), charLine("ZETA"),
    ]
    return [padding + content]
}

// MARK: - Test Suite

final class PDFScreenplayParserTests: XCTestCase {
    let parser = PDFScreenplayParser()

    // MARK: - normalizeCharacterName

    func test_normalize_contd_stripped() {
        XCTAssertEqual(parser.normalizeCharacterName("HAMLET (CONT'D)"), "HAMLET")
    }

    func test_normalize_contd_withDot_stripped() {
        XCTAssertEqual(parser.normalizeCharacterName("HAMLET (CONT'D.)"), "HAMLET")
    }

    func test_normalize_os_stripped() {
        XCTAssertEqual(parser.normalizeCharacterName("JESSICA (O.S.)"), "JESSICA")
    }

    func test_normalize_vo_stripped() {
        XCTAssertEqual(parser.normalizeCharacterName("PAUL (V.O.)"), "PAUL")
    }

    func test_normalize_oc_stripped() {
        XCTAssertEqual(parser.normalizeCharacterName("CHANI (O.C.)"), "CHANI")
    }

    func test_normalize_voOs_stripped() {
        XCTAssertEqual(parser.normalizeCharacterName("STILGAR (V.O./O.S.)"), "STILGAR")
    }

    func test_normalize_noSuffix_unchanged() {
        XCTAssertEqual(parser.normalizeCharacterName("DUNCAN"), "DUNCAN")
    }

    func test_normalize_trailingWhitespace_trimmed() {
        XCTAssertEqual(parser.normalizeCharacterName("LADY JESSICA  "), "LADY JESSICA")
    }

    // MARK: - isPageHeader

    func test_isPageHeader_revDatePattern_true() {
        XCTAssertTrue(parser.isPageHeader("Rev. (06/19/2020)"))
    }

    func test_isPageHeader_revDateWithLeadingText_true() {
        // Revision lines often include colour/draft name before "Rev."
        XCTAssertTrue(parser.isPageHeader("Salmon Rev. (06/19/2020)  5."))
    }

    func test_isPageHeader_barePageNumber_true() {
        XCTAssertTrue(parser.isPageHeader("5."))
        XCTAssertTrue(parser.isPageHeader("42."))
    }

    func test_isPageHeader_regularLine_false() {
        XCTAssertFalse(parser.isPageHeader("DUKE LETO"))
        XCTAssertFalse(parser.isPageHeader("INT. ARRAKIS DESERT - DAY"))
        XCTAssertFalse(parser.isPageHeader("We must show strength."))
    }

    func test_isPageHeader_numberWithoutDot_false() {
        // A line that is JUST a number without a trailing dot is not matched.
        XCTAssertFalse(parser.isPageHeader("5"))
    }

    // MARK: - detectThresholds

    func test_detectThresholds_withEnoughCapsLines_returnsThresholds() {
        let pages: [[SL]] = [[
            SL(text: "HAMLET", minX: 200),
            SL(text: "To be or not to be.", minX: 120),
            SL(text: "OPHELIA", minX: 200),
            SL(text: "My lord.", minX: 120),
            SL(text: "GHOST", minX: 200),
            SL(text: "HORATIO", minX: 200),
            SL(text: "LAERTES", minX: 200),
        ]]
        let result = parser.detectThresholds(from: pages)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.charNameX, 200, accuracy: 1)
        XCTAssertEqual(result!.dialogueX, 120, accuracy: 1)
    }

    func test_detectThresholds_fewerThan5CapsLines_returnsNil() {
        let pages: [[SL]] = [[
            SL(text: "HAMLET", minX: 200),
            SL(text: "OPHELIA", minX: 200),
            SL(text: "some action text", minX: 70),
        ]]
        XCTAssertNil(parser.detectThresholds(from: pages))
    }

    func test_detectThresholds_scanOnlyFirst10Pages() {
        // Pages 0–9 have no ALL-CAPS lines; page 10 does. Should still return nil.
        let emptyPages = Array(repeating: [SL](), count: 10)
        let latePage: [SL] = [
            SL(text: "HERO", minX: 200),
            SL(text: "VILLAIN", minX: 200),
            SL(text: "SIDEKICK", minX: 200),
            SL(text: "MENTOR", minX: 200),
            SL(text: "GUIDE", minX: 200),
        ]
        let pages = emptyPages + [latePage]
        XCTAssertNil(parser.detectThresholds(from: pages))
    }

    func test_detectThresholds_pageHeadersExcluded() {
        // "5." is a page header and must not count toward the ALL-CAPS tally.
        let pages: [[SL]] = [[
            SL(text: "5.", minX: 400),   // page header — excluded
            SL(text: "ROMEO", minX: 200),
            SL(text: "JULIET", minX: 200),
            SL(text: "TYBALT", minX: 200),
            SL(text: "BENVOLIO", minX: 200),
            SL(text: "MERCUTIO", minX: 200),
        ]]
        let result = parser.detectThresholds(from: pages)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.charNameX, 200, accuracy: 1)
    }

    // MARK: - parse(pageLines:) — character name extraction

    func test_parse_characterNamesDetected() {
        let pages = pageWithThresholdLines(then: [
            charLine("HAMLET"),
            dialogueLine("To be or not to be."),
        ])
        let result = parser.parse(pageLines: pages)
        // Only characters who speak at least one line appear in detectedCharacters.
        XCTAssertTrue(result.detectedCharacters.contains("HAMLET"))
        XCTAssertFalse(result.detectedCharacters.contains("ALPHA"))  // padding — no dialogue
    }

    func test_parse_characterName_contdStripped() {
        let pages = pageWithThresholdLines(then: [
            SL(text: "OPHELIA (CONT'D)", minX: 200),
            dialogueLine("My lord, I do not know."),
        ])
        let result = parser.parse(pageLines: pages)
        XCTAssertTrue(result.detectedCharacters.contains("OPHELIA"))
        XCTAssertFalse(result.detectedCharacters.contains("OPHELIA (CONT'D)"))
    }

    func test_parse_characterName_voStripped() {
        let pages = pageWithThresholdLines(then: [
            SL(text: "NARRATOR (V.O.)", minX: 200),
            dialogueLine("In the beginning..."),
        ])
        let result = parser.parse(pageLines: pages)
        XCTAssertTrue(result.detectedCharacters.contains("NARRATOR"))
        XCTAssertFalse(result.detectedCharacters.contains("NARRATOR (V.O.)"))
    }

    // MARK: - parse(pageLines:) — page header exclusion

    func test_parse_pageHeader_notInCharacters() {
        let pages = pageWithThresholdLines(then: [
            SL(text: "5.", minX: 200),   // page header at char-name x
            charLine("HAMLET"),
            dialogueLine("Words, words, words."),
        ])
        let result = parser.parse(pageLines: pages)
        XCTAssertFalse(result.detectedCharacters.contains("5."))
    }

    func test_parse_revisionHeader_excluded() {
        let pages = pageWithThresholdLines(then: [
            SL(text: "Rev. (06/19/2020)", minX: 130),
            charLine("JESSICA"),
            dialogueLine("Tell me of the waters of your homeworld."),
        ])
        let result = parser.parse(pageLines: pages)
        XCTAssertFalse(result.detectedCharacters.contains("Rev. (06/19/2020)"))
        XCTAssertTrue(result.detectedCharacters.contains("JESSICA"))
    }

    func test_parse_trailingRevisionMark_stripped() {
        // A character name ending with " *" should be normalised.
        let pages = pageWithThresholdLines(then: [
            SL(text: "STILGAR *", minX: 200),
            dialogueLine("Usul, we have wormsign."),
        ])
        let result = parser.parse(pageLines: pages)
        XCTAssertTrue(result.detectedCharacters.contains("STILGAR"))
        XCTAssertFalse(result.detectedCharacters.contains("STILGAR *"))
    }

    // MARK: - parse(pageLines:) — parenthetical skipping

    func test_parse_parenthetical_doesNotCreateCharacter() {
        let pages = pageWithThresholdLines(then: [
            charLine("HAMLET"),
            parentheticalLine("aside"),
            dialogueLine("To be or not to be."),
        ])
        let result = parser.parse(pageLines: pages)
        // The parenthetical should not appear in any character name.
        XCTAssertFalse(result.detectedCharacters.contains("(aside)"))
    }

    func test_parse_parenthetical_emittedAsDirection() {
        let pages = pageWithThresholdLines(then: [
            charLine("HAMLET"),
            parentheticalLine("quietly"),
            dialogueLine("Something is rotten."),
        ])
        let result = parser.parse(pageLines: pages)
        // The scene(s) should contain a direction line with the parenthetical text.
        let allLines = result.scenes.flatMap(\.lines)
        let hasParen = allLines.contains { $0.cueType == .direction && $0.text == "(quietly)" }
        XCTAssertTrue(hasParen)
    }

    func test_parse_parenthetical_flushesDialogueBeforeIt() {
        let pages = pageWithThresholdLines(then: [
            charLine("HAMLET"),
            dialogueLine("To be or not to be,"),
            parentheticalLine("pause"),
            dialogueLine("that is the question."),
        ])
        let result = parser.parse(pageLines: pages)
        let hamletLines = result.scenes.flatMap(\.lines).filter { $0.character == "HAMLET" }
        let spokenCount = hamletLines.filter { $0.cueType == .spoken }.count
        // Dialogue before and after the parenthetical becomes two separate spoken lines.
        XCTAssertEqual(spokenCount, 2)
    }

    // MARK: - parse(pageLines:) — scene heading detection

    func test_parse_intSceneHeading_splitsScene() {
        let pages = pageWithThresholdLines(then: [
            actionLine("INT. CASTLE - DAY"),
            charLine("HORATIO"),
            dialogueLine("My lord."),
            actionLine("EXT. BATTLEMENTS - NIGHT"),
            charLine("HAMLET"),
            dialogueLine("The air bites shrewdly."),
        ])
        let result = parser.parse(pageLines: pages)
        let titles = result.scenes.map(\.title)
        XCTAssertTrue(titles.contains("INT. CASTLE - DAY"))
        XCTAssertTrue(titles.contains("EXT. BATTLEMENTS - NIGHT"))
    }

    func test_parse_sceneHeadingWithLeadingNumber_detected() {
        let pages = pageWithThresholdLines(then: [
            actionLine("2A. INT. VESTIBULE - NIGHT"),
            charLine("GUARD"),
            dialogueLine("Halt, who goes there?"),
        ])
        let result = parser.parse(pageLines: pages)
        let titles = result.scenes.map(\.title)
        XCTAssertTrue(titles.contains("2A. INT. VESTIBULE - NIGHT"))
    }

    func test_parse_allCapsActionWord_doesNotCreateCharacter() {
        // ALL-CAPS words in the action zone (low x) must not become character names.
        let pages = pageWithThresholdLines(then: [
            actionLine("FADE IN:"),
            charLine("PAUL"),
            dialogueLine("I must not fear."),
        ])
        let result = parser.parse(pageLines: pages)
        XCTAssertFalse(result.detectedCharacters.contains("FADE IN:"))
        XCTAssertTrue(result.detectedCharacters.contains("PAUL"))
    }

    // MARK: - parse(pageLines:) — dialogue and action classification

    func test_parse_actionLine_capturedAsDirection() {
        let pages = pageWithThresholdLines(then: [
            actionLine("The worm rises from the sand."),
            charLine("STILGAR"),
            dialogueLine("Ride the worm."),
        ])
        let result = parser.parse(pageLines: pages)
        let allLines = result.scenes.flatMap(\.lines)
        let directionLine = allLines.first { $0.cueType == .direction && $0.character.isEmpty }
        XCTAssertNotNil(directionLine)
        XCTAssertEqual(directionLine?.text, "The worm rises from the sand.")
    }

    func test_parse_multiLineDialogue_joinedWithSpace() {
        let pages = pageWithThresholdLines(then: [
            charLine("PAUL"),
            dialogueLine("I must not fear."),
            dialogueLine("Fear is the mind-killer."),
        ])
        let result = parser.parse(pageLines: pages)
        let spoken = result.scenes.flatMap(\.lines).filter { $0.character == "PAUL" && $0.cueType == .spoken }
        XCTAssertEqual(spoken.count, 1)
        XCTAssertEqual(spoken[0].text, "I must not fear. Fear is the mind-killer.")
    }

    func test_parse_detectedCharacters_sortedAlphabetically() {
        // Only the content lines are checked for sorting — padding chars are also present.
        let pages = pageWithThresholdLines(then: [
            charLine("ROMEO"),
            dialogueLine("First line."),
            charLine("HAMLET"),
            dialogueLine("Second line."),
            charLine("JULIET"),
            dialogueLine("Third line."),
        ])
        let result = parser.parse(pageLines: pages)
        let filtered = result.detectedCharacters.filter { ["ROMEO", "HAMLET", "JULIET"].contains($0) }
        XCTAssertEqual(filtered, ["HAMLET", "JULIET", "ROMEO"])
    }

    func test_parse_noThresholdsDetected_returnsEmptyResult() {
        // Two ALL-CAPS lines is below the minimum threshold of 5.
        let pages: [[SL]] = [[
            SL(text: "HERO", minX: 200),
            SL(text: "VILLAIN", minX: 200),
        ]]
        let result = parser.parse(pageLines: pages)
        XCTAssertTrue(result.scenes.isEmpty)
        XCTAssertTrue(result.detectedCharacters.isEmpty)
    }
}
