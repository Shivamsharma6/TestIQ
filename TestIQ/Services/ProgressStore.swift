import Foundation

/// The persisted player profile. One Codable value, one file, atomic writes.
struct PlayerProgress: Codable, Equatable {
    var unlockedLevelID: Int = 1
    /// Every finished attempt, keyed by level. The assessment is recomputed from these, so
    /// the report can always be regenerated rather than only produced once at the end.
    var levelResults: [Int: LevelResult] = [:]
    var lastAssessment: Assessment?
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var hasSeenIntro: Bool = false

    // MARK: - Derived

    func stars(for levelID: Int) -> Int { self.levelResults[levelID]?.stars ?? 0 }
    func attempts(for levelID: Int) -> Int { self.levelResults[levelID]?.attempts ?? 1 }
    func isUnlocked(_ levelID: Int) -> Bool { levelID <= self.unlockedLevelID }
    func isCleared(_ levelID: Int) -> Bool { self.stars(for: levelID) > 0 }

    var totalStars: Int { self.levelResults.values.reduce(0) { $0 + $1.stars } }
    var clearedCount: Int { self.levelResults.values.filter(\.isCleared).count }
    var maxStars: Int { LevelCatalog.count * 3 }
    var bestResults: [LevelResult] { self.levelResults.values.sorted { $0.levelID < $1.levelID } }

    var nextLevelID: Int {
        LevelCatalog.all.first { !self.isCleared($0.id) }?.id ?? LevelCatalog.finalLevelID
    }

    var hasFinishedAscent: Bool { self.clearedCount >= LevelCatalog.count }

    var summary: RunSummary { RunSummary(levelResults: self.bestResults) }
}

/// Reads and writes `PlayerProgress`.
///
/// A corrupt or missing file yields a fresh profile rather than throwing: losing progress
/// is annoying, but refusing to launch is unforgivable.
@MainActor
final class ProgressStore {
    static let shared = ProgressStore()

    private let url: URL
    private var cached: PlayerProgress?

    init(url: URL? = nil) {
        self.url = url ?? Self.defaultURL()
    }

    static func defaultURL() -> URL {
        let manager = FileManager.default
        let base = (try? manager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? manager.temporaryDirectory
        // A failure here is not fatal: writes fall back to `Data.write`, which creates
        // intermediate directories itself.
        try? manager.createDirectory(at: base, withIntermediateDirectories: true, attributes: nil)
        let directory = base
        return directory.appendingPathComponent("progress.json", isDirectory: false)
    }

    /// Dates are written as ISO 8601 rather than Foundation's default seconds-since-2001
    /// number. The default is unreadable in a file that also has to survive a schema
    /// change, and it is the kind of thing that silently fails to decode.
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    func load() -> PlayerProgress {
        if let cached { return cached }
        guard let data = try? Data(contentsOf: self.url),
              let decoded = try? Self.makeDecoder().decode(PlayerProgress.self, from: data) else {
            // A corrupt or unreadable profile costs progress, not a launch failure.
            let fresh = PlayerProgress()
            self.cached = fresh
            return fresh
        }
        self.cached = decoded
        return decoded
    }

    func save(_ progress: PlayerProgress) {
        self.cached = progress
        guard let data = try? Self.makeEncoder().encode(progress) else { return }
        // `.atomic` so an interrupted write can never leave a half-written profile.
        try? data.write(to: self.url, options: .atomic)
    }

    /// Records a finished floor. The better attempt is kept, so replaying can only ever
    /// improve a score — never quietly damage one already earned.
    func record(_ result: LevelResult) {
        var progress = self.load()
        let levelID = result.levelID

        if let existing = progress.levelResults[levelID] {
            progress.levelResults[levelID] = existing.bestPerformance(excluding: result).mergingAttempts(from: result)
        } else {
            progress.levelResults[levelID] = result
        }

        if result.isCleared {
            progress.unlockedLevelID = min(
                LevelCatalog.finalLevelID, max(progress.unlockedLevelID, levelID + 1)
            )
        }
        self.save(progress)
    }

    func reset() {
        let fresh = PlayerProgress()
        self.cached = fresh
        try? FileManager.default.removeItem(at: self.url)
        self.save(fresh)
    }
}

extension LevelResult {
    /// Carries the attempt counter forward from a newer attempt while keeping whichever
    /// attempt actually scored better.
    func mergingAttempts(from newer: LevelResult) -> LevelResult {
        var copy = self
        copy.attempts = max(self.attempts, newer.attempts)
        return copy
    }
}