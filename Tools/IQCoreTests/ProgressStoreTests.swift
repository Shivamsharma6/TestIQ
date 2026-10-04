import XCTest
@testable import IQCore

@MainActor
final class ProgressStoreTests: XCTestCase {
    func testRoundHistorySurvivesReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("progress.json")
        let store = ProgressStore(url: url)
        store.record(LevelResult(id: "one", levelID: 1, items: [], stars: 1, score: 100, bestStreak: 1))
        XCTAssertEqual(ProgressStore(url: url).load().attemptHistory.map(\.id), ["one"])
        XCTAssertNil(store.lastError)
    }

    func testCorruptSaveIsPreservedBeforeWritingFreshProgress() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("progress.json")
        let original = Data("unfinished-old-save".utf8)
        try original.write(to: url)
        let store = ProgressStore(url: url)
        XCTAssertTrue(store.load().attemptHistory.isEmpty)
        XCTAssertNotNil(store.lastError)
        store.save(PlayerProgress())
        let backup = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.hasPrefix("progress-recovery-") })
        XCTAssertEqual(try Data(contentsOf: backup), original)
        XCTAssertNil(store.lastError)
    }

    func testFailedWriteKeepsSessionProgressAndReportsFailure() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("blocking parent".utf8).write(to: file)
        let store = ProgressStore(url: file.appendingPathComponent("progress.json"))
        var progress = PlayerProgress()
        progress.soundEnabled = false
        store.save(progress)
        XCTAssertFalse(store.load().soundEnabled)
        XCTAssertNotNil(store.lastError)
    }
}
