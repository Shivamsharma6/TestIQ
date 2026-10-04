import XCTest
@testable import IQCore

final class ArcadeRulesTests: XCTestCase {
    func testTwoStarThresholdCannotBypassSummitClearGate() throws {
        let level = try XCTUnwrap(LevelCatalog.level(10))
        let items = (0..<12).map {
            ItemResult(id: "\($0)", levelID: 10, kind: .sequence, domain: .pattern,
                       theta: 3, skillTag: "sequence", correct: $0 < 9,
                       elapsed: 5, timeLimit: 20, hintsUsed: 0)
        }
        let result = StarRules.evaluate(items: items, level: level, score: 900, bestStreak: 9)
        XCTAssertEqual(result.accuracy, 0.75)
        XCTAssertEqual(result.stars, 0)
        XCTAssertFalse(result.isCleared)
    }
}
