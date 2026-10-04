import Foundation

/// Reads and writes `PlayerProgress`.
///
/// A corrupt or missing file yields a fresh profile rather than throwing: losing progress
/// is annoying, but refusing to launch is unforgivable.
@MainActor
final class ProgressStore {
    static let shared = ProgressStore()

    private let url: URL
    private var cached: PlayerProgress?
    private var needsRecoveryCopy = false
    private(set) var lastError: String?

    init(url: URL? = nil) {
        self.url = url ?? Self.defaultURL()
    }

    static func defaultURL() -> URL {
        let manager = FileManager.default
        let base = (try? manager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? manager.temporaryDirectory
        // Save retries directory creation and reports any failure without crashing.
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
        guard FileManager.default.fileExists(atPath: self.url.path) else {
            let fresh = PlayerProgress()
            self.cached = fresh
            return fresh
        }
        do {
            let decoded = try Self.makeDecoder().decode(PlayerProgress.self, from: Data(contentsOf: self.url))
            self.cached = decoded
            return decoded
        } catch {
            self.needsRecoveryCopy = true
            self.lastError = "Your saved progress could not be read. The original file will be preserved before saving a fresh profile."
            let fresh = PlayerProgress()
            self.cached = fresh
            return fresh
        }
    }

    func save(_ progress: PlayerProgress) {
        self.cached = progress
        do {
            let directory = self.url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if self.needsRecoveryCopy {
                let recovery = directory.appendingPathComponent("progress-recovery-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: self.url, to: recovery)
                self.needsRecoveryCopy = false
            }
            try Self.makeEncoder().encode(progress).write(to: self.url, options: .atomic)
            self.lastError = nil
        } catch {
            self.lastError = "Your latest progress is available for this session, but could not be saved. Free some device storage and try again before closing the app."
        }
    }

    /// Records every completed round while retaining earned rewards and personal records.
    func record(_ result: LevelResult) {
        var progress = self.load()
        progress.record(result)
        self.save(progress)
    }

    func reset() {
        let fresh = PlayerProgress()
        self.save(fresh)
    }
}
