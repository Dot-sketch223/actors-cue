import XCTest
import SwiftData
@testable import ActorsCue

@MainActor
final class ModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Script.self, ScriptScene.self, Line.self, RunSession.self,
            configurations: config
        )
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
    }

    // MARK: - RunSession.stumbedCount

    func test_stumbedCount_matchesIDArrayLength() {
        let session = RunSession(scriptID: UUID(), stumbedLineIDs: [UUID(), UUID(), UUID()])
        XCTAssertEqual(session.stumbedCount, 3)
    }

    func test_stumbedCount_emptyArray_isZero() {
        let session = RunSession(scriptID: UUID(), stumbedLineIDs: [])
        XCTAssertEqual(session.stumbedCount, 0)
    }

    // MARK: - Script.allCharacters

    func test_allCharacters_returnsAllUniqueNames() throws {
        let line1 = Line(character: "ROMEO", text: "Hello.", cueType: .spoken, orderIndex: 0)
        let line2 = Line(character: "JULIET", text: "Hi.", cueType: .spoken, orderIndex: 1)
        context.insert(line1)
        context.insert(line2)
        let scene = ScriptScene(title: "Scene 1", orderIndex: 0, lines: [line1, line2])
        context.insert(scene)
        let script = Script(title: "Romeo & Juliet", scenes: [scene])
        context.insert(script)
        try context.save()

        XCTAssertEqual(Set(script.allCharacters), Set(["ROMEO", "JULIET"]))
    }

    func test_allCharacters_deduplicatesAcrossScenes() throws {
        let line1 = Line(character: "ROMEO", text: "A.", cueType: .spoken, orderIndex: 0)
        let line2 = Line(character: "JULIET", text: "B.", cueType: .spoken, orderIndex: 1)
        let line3 = Line(character: "ROMEO", text: "C.", cueType: .spoken, orderIndex: 0)
        context.insert(line1); context.insert(line2); context.insert(line3)
        let scene1 = ScriptScene(title: "Scene 1", orderIndex: 0, lines: [line1, line2])
        let scene2 = ScriptScene(title: "Scene 2", orderIndex: 1, lines: [line3])
        context.insert(scene1); context.insert(scene2)
        let script = Script(title: "Test", scenes: [scene1, scene2])
        context.insert(script)
        try context.save()

        // ROMEO appears in both scenes but should only count once
        XCTAssertEqual(Set(script.allCharacters), Set(["ROMEO", "JULIET"]))
        XCTAssertEqual(script.allCharacters.count, 2)
    }

    func test_allCharacters_emptyScript_isEmpty() throws {
        let script = Script(title: "Empty", scenes: [])
        context.insert(script)
        try context.save()

        XCTAssertTrue(script.allCharacters.isEmpty)
    }

    func test_allCharacters_skipsEmptyCharacterNames() throws {
        let line = Line(character: "", text: "Unnamed line.", cueType: .spoken, orderIndex: 0)
        context.insert(line)
        let scene = ScriptScene(title: "Scene 1", orderIndex: 0, lines: [line])
        context.insert(scene)
        let script = Script(title: "Test", scenes: [scene])
        context.insert(script)
        try context.save()

        XCTAssertTrue(script.allCharacters.isEmpty)
    }

    // MARK: - Script.renameCharacter

    func test_renameCharacter_updatesAllMatchingLines() throws {
        let line1 = Line(character: "Ham.", text: "To be.", cueType: .spoken, orderIndex: 0)
        let line2 = Line(character: "Ham.", text: "Or not.", cueType: .spoken, orderIndex: 1)
        context.insert(line1); context.insert(line2)
        let scene = ScriptScene(title: "Scene 1", orderIndex: 0, lines: [line1, line2])
        context.insert(scene)
        let script = Script(title: "Test", scenes: [scene])
        context.insert(script)
        try context.save()

        script.renameCharacter(from: "Ham.", to: "HAMLET")

        XCTAssertEqual(line1.character, "HAMLET")
        XCTAssertEqual(line2.character, "HAMLET")
    }

    func test_renameCharacter_updatesUserCharacters() throws {
        let line = Line(character: "Ham.", text: "To be.", cueType: .spoken, orderIndex: 0)
        context.insert(line)
        let scene = ScriptScene(title: "Scene 1", orderIndex: 0, lines: [line])
        context.insert(scene)
        let script = Script(title: "Test", scenes: [scene], userCharacters: ["Ham."])
        context.insert(script)
        try context.save()

        script.renameCharacter(from: "Ham.", to: "HAMLET")

        XCTAssertEqual(script.userCharacters, ["HAMLET"])
    }

    func test_renameCharacter_mergesIntoExistingCharacter() throws {
        let line1 = Line(character: "Ham.", text: "To be.", cueType: .spoken, orderIndex: 0)
        let line2 = Line(character: "HAMLET", text: "Or not.", cueType: .spoken, orderIndex: 1)
        context.insert(line1); context.insert(line2)
        let scene = ScriptScene(title: "Scene 1", orderIndex: 0, lines: [line1, line2])
        context.insert(scene)
        let script = Script(title: "Test", scenes: [scene])
        context.insert(script)
        try context.save()

        script.renameCharacter(from: "Ham.", to: "HAMLET")

        XCTAssertEqual(Set(script.allCharacters), Set(["HAMLET"]))
        XCTAssertEqual(line1.character, "HAMLET")
    }

    func test_renameCharacter_merge_removesOldFromUserCharacters() throws {
        let line1 = Line(character: "Ham.", text: "To be.", cueType: .spoken, orderIndex: 0)
        let line2 = Line(character: "HAMLET", text: "Or not.", cueType: .spoken, orderIndex: 1)
        context.insert(line1); context.insert(line2)
        let scene = ScriptScene(title: "Scene 1", orderIndex: 0, lines: [line1, line2])
        context.insert(scene)
        let script = Script(title: "Test", scenes: [scene], userCharacters: ["Ham.", "HAMLET"])
        context.insert(script)
        try context.save()

        script.renameCharacter(from: "Ham.", to: "HAMLET")

        XCTAssertEqual(script.userCharacters, ["HAMLET"])
    }

    func test_renameCharacter_emptyNewName_isNoOp() throws {
        let line = Line(character: "HAMLET", text: "To be.", cueType: .spoken, orderIndex: 0)
        context.insert(line)
        let scene = ScriptScene(title: "Scene 1", orderIndex: 0, lines: [line])
        context.insert(scene)
        let script = Script(title: "Test", scenes: [scene])
        context.insert(script)
        try context.save()

        script.renameCharacter(from: "HAMLET", to: "")

        XCTAssertEqual(line.character, "HAMLET")
    }

    func test_renameCharacter_sameNameIsNoOp() throws {
        let line = Line(character: "HAMLET", text: "To be.", cueType: .spoken, orderIndex: 0)
        context.insert(line)
        let scene = ScriptScene(title: "Scene 1", orderIndex: 0, lines: [line])
        context.insert(scene)
        let script = Script(title: "Test", scenes: [scene])
        context.insert(script)
        try context.save()

        script.renameCharacter(from: "HAMLET", to: "HAMLET")

        XCTAssertEqual(line.character, "HAMLET")
    }

    func test_renameCharacter_acrossMultipleScenes() throws {
        let line1 = Line(character: "Ham.", text: "First.", cueType: .spoken, orderIndex: 0)
        let line2 = Line(character: "Ham.", text: "Second.", cueType: .spoken, orderIndex: 0)
        context.insert(line1); context.insert(line2)
        let scene1 = ScriptScene(title: "Scene 1", orderIndex: 0, lines: [line1])
        let scene2 = ScriptScene(title: "Scene 2", orderIndex: 1, lines: [line2])
        context.insert(scene1); context.insert(scene2)
        let script = Script(title: "Test", scenes: [scene1, scene2])
        context.insert(script)
        try context.save()

        script.renameCharacter(from: "Ham.", to: "HAMLET")

        XCTAssertEqual(line1.character, "HAMLET")
        XCTAssertEqual(line2.character, "HAMLET")
    }

    func test_renameCharacter_onlyExactMatches() throws {
        // "HAMLET" rename should not touch a character named "HAMLETED"
        let line1 = Line(character: "HAMLET", text: "To be.", cueType: .spoken, orderIndex: 0)
        let line2 = Line(character: "HAMLETED", text: "Or not.", cueType: .spoken, orderIndex: 1)
        context.insert(line1); context.insert(line2)
        let scene = ScriptScene(title: "Scene 1", orderIndex: 0, lines: [line1, line2])
        context.insert(scene)
        let script = Script(title: "Test", scenes: [scene])
        context.insert(script)
        try context.save()

        script.renameCharacter(from: "HAMLET", to: "PRINCE")

        XCTAssertEqual(line1.character, "PRINCE")
        XCTAssertEqual(line2.character, "HAMLETED")
    }
}
