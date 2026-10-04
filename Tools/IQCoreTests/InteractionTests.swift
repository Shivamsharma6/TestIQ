import XCTest
@testable import IQCore

final class InteractionTests: XCTestCase {
    func testEveryInteractionHasTheRightFirstUseLesson() {
        XCTAssertEqual(PuzzleInteraction.Lesson.forKind(.memorySequence), .memorySequence)
        XCTAssertEqual(PuzzleInteraction.Lesson.forKind(.gridRecall), .gridRecall)
        XCTAssertEqual(PuzzleInteraction.Lesson.forKind(.ordering), .order)
        XCTAssertEqual(PuzzleInteraction.Lesson.forKind(.anagram), .wordTiles)
        for kind in PuzzleKind.allCases where kind.archetype == .choice {
            XCTAssertEqual(PuzzleInteraction.Lesson.forKind(kind), .choice)
        }
    }

    func testEchoCommitsWhenTheFinalCorrectTapArrives() {
        let tap = PuzzleInteraction.memoryTap(2, current: [0, 1], expected: [0, 1, 2], gridRecall: false)
        XCTAssertEqual(tap.indices, [0, 1, 2])
        XCTAssertTrue(tap.shouldSubmit)
    }

    func testEchoCanRepeatTheSameTileInItsSequence() {
        let tap = PuzzleInteraction.memoryTap(0, current: [0, 1], expected: [0, 1, 0], gridRecall: false)
        XCTAssertEqual(tap.indices, [0, 1, 0])
        XCTAssertTrue(tap.shouldSubmit)
    }

    func testWrongEchoPrefixCommitsImmediately() {
        let tap = PuzzleInteraction.memoryTap(2, current: [0], expected: [0, 1, 2], gridRecall: false)
        XCTAssertTrue(tap.shouldSubmit)
        XCTAssertFalse(PuzzleInteraction.memoryMatches(tap.indices, expected: [0, 1, 2], gridRecall: false))
    }

    func testGridRecallAcceptsTheRightTilesInAnyOrder() {
        XCTAssertTrue(PuzzleInteraction.memoryMatches([4, 0, 2], expected: [0, 2, 4], gridRecall: true))
        XCTAssertFalse(PuzzleInteraction.memoryMatches([4, 0, 2], expected: [0, 2, 4], gridRecall: false))
        XCTAssertFalse(PuzzleInteraction.memoryMatches([0, 0, 2], expected: [0, 2, 4], gridRecall: true))
    }

    func testGridRecallIgnoresRepeatedSelectionAndWaitsForTheFullSet() {
        let repeated = PuzzleInteraction.memoryTap(0, current: [0], expected: [0, 2], gridRecall: true)
        XCTAssertEqual(repeated.indices, [0])
        XCTAssertFalse(repeated.shouldSubmit)
        let final = PuzzleInteraction.memoryTap(2, current: repeated.indices, expected: [0, 2], gridRecall: true)
        XCTAssertTrue(final.shouldSubmit)
    }

    func testUndoRestoresTheActualDuplicateLetterTile() {
        let tiles = ["L", "E", "V", "E", "L"]
        var draft = WordTileDraft()
        draft.append(0, tiles: tiles)
        draft.append(1, tiles: tiles)
        draft.undo(tiles: tiles)
        XCTAssertEqual(draft.indices, [0])
        XCTAssertEqual(draft.letters(in: tiles), ["L"])
        draft.append(1, tiles: tiles)
        draft.append(3, tiles: tiles)
        draft.undo(tiles: tiles)
        XCTAssertEqual(draft.indices, [0, 1])
    }

    func testWordDraftRejectsInvalidAndUsedTileIndices() {
        var draft = WordTileDraft()
        draft.append(-1, tiles: ["A", "A"])
        draft.append(2, tiles: ["A", "A"])
        draft.append(0, tiles: ["A", "A"])
        draft.append(0, tiles: ["A", "A"])
        draft.append(1, tiles: ["A", "A"])
        XCTAssertEqual(draft.indices, [0, 1])
    }
}
