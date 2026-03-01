import XCTest
@testable import ActorsCue

final class PlainTextParserTests: XCTestCase {
    let parser = PlainTextParser()

    // MARK: - Inline colon format

    func test_colonFormat_parsesCharacterAndDialogue() {
        let result = parser.parse(text: "HAMLET: To be or not to be.")
        let lines = result.scenes[0].lines

        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].character, "HAMLET")
        XCTAssertEqual(lines[0].text, "To be or not to be.")
        XCTAssertEqual(lines[0].cueType, .spoken)
    }

    func test_colonFormat_multipleCharacters() {
        let text = """
        ROMEO: But soft, what light through yonder window breaks?
        JULIET: O Romeo, Romeo, wherefore art thou Romeo?
        """
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].character, "ROMEO")
        XCTAssertEqual(lines[1].character, "JULIET")
    }

    func test_colonFormat_characterNameWithSpaces() {
        let result = parser.parse(text: "STAGE MANAGER: Places, everyone.")
        let lines = result.scenes[0].lines

        XCTAssertEqual(lines[0].character, "STAGE MANAGER")
        XCTAssertEqual(lines[0].text, "Places, everyone.")
    }

    func test_colonFormat_lowercaseNameNotParsed() {
        let result = parser.parse(text: "hamlet: To be or not to be.")
        XCTAssertTrue(result.scenes[0].lines.isEmpty)
        XCTAssertTrue(result.detectedCharacters.isEmpty)
    }

    // MARK: - Separate-line format

    func test_separateFormat_parsesCharacterAndDialogue() {
        let text = "HAMLET\nTo be or not to be."
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].character, "HAMLET")
        XCTAssertEqual(lines[0].text, "To be or not to be.")
    }

    func test_separateFormat_multiLineDialogueJoined() {
        let text = "HAMLET\nTo be or not to be,\nthat is the question."
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].text, "To be or not to be, that is the question.")
    }

    func test_separateFormat_multipleCharacters() {
        let text = """
        ROMEO
        But soft, what light through yonder window breaks?

        JULIET
        O Romeo, Romeo, wherefore art thou Romeo?
        """
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].character, "ROMEO")
        XCTAssertEqual(lines[1].character, "JULIET")
    }

    func test_separateFormat_standaloneCharacterNameWithNoDialogueProducesNoLine() {
        // A character name with no following dialogue should not produce a line
        let result = parser.parse(text: "HAMLET")
        XCTAssertTrue(result.scenes[0].lines.isEmpty)
    }

    // MARK: - Mixed formats

    func test_mixedFormats_bothParsed() {
        let text = """
        ROMEO: But soft, what light?

        JULIET
        O Romeo, Romeo.
        """
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].character, "ROMEO")
        XCTAssertEqual(lines[1].character, "JULIET")
    }

    // MARK: - Stage direction filtering

    func test_colonFormat_stageDirectionLineSkipped() {
        let text = """
        HAMLET: To be or not to be.
        (He pauses dramatically)
        OPHELIA: My lord.
        """
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].character, "HAMLET")
        XCTAssertEqual(lines[1].character, "OPHELIA")
    }

    // MARK: - Character name detection rules

    func test_nameWithDigit_notDetected() {
        let result = parser.parse(text: "ACT1: Something happens.")
        XCTAssertTrue(result.detectedCharacters.isEmpty)
    }

    func test_singleCharName_notDetected() {
        // Names must be at least 2 characters
        let result = parser.parse(text: "A: Some text.")
        XCTAssertTrue(result.detectedCharacters.isEmpty)
    }

    func test_mixedCaseName_notDetected() {
        let result = parser.parse(text: "Hamlet: Something.")
        XCTAssertTrue(result.detectedCharacters.isEmpty)
    }

    // MARK: - detectedCharacters

    func test_detectedCharacters_sortedAlphabetically() {
        let text = """
        ROMEO: First.
        HAMLET: Second.
        JULIET: Third.
        """
        let result = parser.parse(text: text)
        XCTAssertEqual(result.detectedCharacters, ["HAMLET", "JULIET", "ROMEO"])
    }

    func test_detectedCharacters_deduplicatedAcrossLines() {
        let text = """
        ROMEO: First line.
        JULIET: Response.
        ROMEO: Second line.
        """
        let result = parser.parse(text: text)
        XCTAssertEqual(result.detectedCharacters, ["JULIET", "ROMEO"])
    }

    // MARK: - Scene output

    func test_alwaysReturnsSingleScene() {
        let result = parser.parse(text: "HAMLET: Something.")
        XCTAssertEqual(result.scenes.count, 1)
        XCTAssertEqual(result.scenes[0].title, "Scene 1")
    }

    func test_emptyInput_returnsEmptyScene() {
        let result = parser.parse(text: "")
        XCTAssertEqual(result.scenes.count, 1)
        XCTAssertEqual(result.scenes[0].lines.count, 0)
        XCTAssertTrue(result.detectedCharacters.isEmpty)
    }

    func test_noCharactersDetected_returnsEmptyCharacterList() {
        let result = parser.parse(text: "This is just some plain text with no dialogue.")
        XCTAssertTrue(result.detectedCharacters.isEmpty)
    }
}
