import XCTest
@testable import ActorsCue

final class FountainParserTests: XCTestCase {
    let parser = FountainParser()

    // MARK: - Scene headings

    func test_intSceneHeading_detected() {
        let text = "INT. LIVING ROOM - DAY\n\nHAMLET\nTo be or not to be."
        let result = parser.parse(text: text)

        XCTAssertEqual(result.scenes.count, 1)
        XCTAssertEqual(result.scenes[0].title, "INT. LIVING ROOM - DAY")
    }

    func test_extSceneHeading_detected() {
        let text = "EXT. GARDEN - NIGHT\n\nROMEO\nWhat light through yonder window breaks?"
        let result = parser.parse(text: text)

        XCTAssertEqual(result.scenes[0].title, "EXT. GARDEN - NIGHT")
    }

    func test_intExtVariant_detected() {
        let text = "INT/EXT. CAR - DAY\n\nDRIVER\nLet's go."
        let result = parser.parse(text: text)

        XCTAssertEqual(result.scenes[0].title, "INT/EXT. CAR - DAY")
    }

    func test_forcedSceneHeading_dotPrefixStripped() {
        let text = ".OPENING TITLES\n\nNARRATOR\nOnce upon a time."
        let result = parser.parse(text: text)

        XCTAssertEqual(result.scenes[0].title, "OPENING TITLES")
    }

    func test_multipleScenes_splitCorrectly() {
        let text = """
        INT. ROOM A - DAY

        ALICE
        First scene.

        EXT. GARDEN - NIGHT

        BOB
        Second scene.
        """
        let result = parser.parse(text: text)

        XCTAssertEqual(result.scenes.count, 2)
        XCTAssertEqual(result.scenes[0].title, "INT. ROOM A - DAY")
        XCTAssertEqual(result.scenes[0].lines.count, 1)
        XCTAssertEqual(result.scenes[1].title, "EXT. GARDEN - NIGHT")
        XCTAssertEqual(result.scenes[1].lines.count, 1)
    }

    func test_noSceneHeading_allLinesInScene1() {
        let text = "\nHAMLET\nTo be or not to be.\n\nOPHELIA\nMy lord."
        let result = parser.parse(text: text)

        XCTAssertEqual(result.scenes.count, 1)
        XCTAssertEqual(result.scenes[0].title, "Scene 1")
        XCTAssertEqual(result.scenes[0].lines.count, 2)
    }

    // MARK: - Character cues

    func test_characterCue_precededByBlankLine_detected() {
        let text = "\nHAMLET\nTo be or not to be."
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].character, "HAMLET")
    }

    func test_characterCue_notPrecededByBlankLine_ignored() {
        // Per Fountain spec, a character cue must be preceded by a blank line
        let text = "Some narrative text.\nHAMLET\nThis dialogue should be ignored."
        let result = parser.parse(text: text)

        XCTAssertTrue(result.detectedCharacters.isEmpty)
    }

    func test_dualDialogueCaret_strippedFromCharacterName() {
        let text = "\nHAMLET ^\nTo be.\n\nOPHELIA ^\nNot to be."
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines[0].character, "HAMLET")
        XCTAssertEqual(lines[1].character, "OPHELIA")
    }

    func test_cueType_isSpoken() {
        let text = "\nHAMLET\nTo be."
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines[0].cueType, .spoken)
    }

    // MARK: - Parentheticals captured as stage directions

    func test_parenthetical_capturedAsDirection() {
        let text = "\nHAMLET\n(aside)\nTo be or not to be."
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].cueType, .direction)
        XCTAssertEqual(lines[0].text, "(aside)")
        XCTAssertEqual(lines[0].character, "HAMLET")
        XCTAssertEqual(lines[1].cueType, .spoken)
        XCTAssertEqual(lines[1].text, "To be or not to be.")
    }

    func test_parenthetical_midDialogue_flushesAndResumes() {
        // Dialogue before and after a parenthetical should become separate spoken lines
        let text = "\nHAMLET\nTo be or not to be,\n(aside)\nthat is the question."
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].cueType, .spoken)
        XCTAssertEqual(lines[0].text, "To be or not to be,")
        XCTAssertEqual(lines[1].cueType, .direction)
        XCTAssertEqual(lines[1].text, "(aside)")
        XCTAssertEqual(lines[2].cueType, .spoken)
        XCTAssertEqual(lines[2].text, "that is the question.")
    }

    func test_parenthetical_notInDetectedCharacters() {
        // Parenthetical direction lines must not add their character to detectedCharacters
        // (spoken lines still do)
        let text = "\nHAMLET\n(aside)\nTo be or not to be."
        let result = parser.parse(text: text)

        XCTAssertEqual(result.detectedCharacters, ["HAMLET"])
    }

    // MARK: - Dialogue collection

    func test_multiLineDialogue_joinedWithSpace() {
        let text = "\nHAMLET\nTo be or not to be,\nthat is the question."
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines[0].text, "To be or not to be, that is the question.")
    }

    func test_dialogueStopsAtBlankLine() {
        let text = "\nHAMLET\nFirst line.\n\nOPHELIA\nSecond line."
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "First line.")
        XCTAssertEqual(lines[1].character, "OPHELIA")
    }

    // MARK: - detectedCharacters

    func test_detectedCharacters_sortedAlphabetically() {
        let text = "\nROMEO\nLine one.\n\nHAMLET\nLine two.\n\nJULIET\nLine three."
        let result = parser.parse(text: text)

        XCTAssertEqual(result.detectedCharacters, ["HAMLET", "JULIET", "ROMEO"])
    }

    func test_detectedCharacters_deduplicatedAcrossLines() {
        let text = "\nHAMLET\nFirst.\n\nOPHELIA\nSecond.\n\nHAMLET\nThird."
        let result = parser.parse(text: text)

        XCTAssertEqual(result.detectedCharacters, ["HAMLET", "OPHELIA"])
    }

    // MARK: - Edge cases

    func test_emptyInput_returnsNoContent() {
        let result = parser.parse(text: "")

        XCTAssertTrue(result.scenes.isEmpty)
        XCTAssertTrue(result.detectedCharacters.isEmpty)
    }

    func test_sceneHeadingWithNoLines_notIncluded() {
        // A scene with a heading but no character lines should not appear in scenes
        let text = "INT. EMPTY ROOM - DAY\n"
        let result = parser.parse(text: text)

        XCTAssertTrue(result.scenes.isEmpty)
    }

    // MARK: - Action lines (stage directions outside dialogue blocks)

    func test_actionLine_capturedAsDirection() {
        let text = "The ghost of Hamlet's father appears.\n\nHAMLET\nO, speak!"
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines[0].cueType, .direction)
        XCTAssertEqual(lines[0].text, "The ghost of Hamlet's father appears.")
        XCTAssertEqual(lines[0].character, "")
    }

    func test_actionLine_emptyCharacter() {
        let text = "Lights fade to black."
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].character, "")
        XCTAssertEqual(lines[0].cueType, .direction)
    }

    func test_actionLine_notInDetectedCharacters() {
        let text = "Lights fade.\n\nHAMLET\nTo be."
        let result = parser.parse(text: text)

        XCTAssertEqual(result.detectedCharacters, ["HAMLET"])
    }

    func test_actionLine_appearsInSceneBetweenDialogue() {
        let text = "\nHAMLET\nTo be.\n\nA long pause.\n\nOPHELIA\nMy lord."
        let lines = parser.parse(text: text).scenes[0].lines

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].cueType, .spoken)
        XCTAssertEqual(lines[1].cueType, .direction)
        XCTAssertEqual(lines[1].text, "A long pause.")
        XCTAssertEqual(lines[2].cueType, .spoken)
    }
}
