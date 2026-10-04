import AVFoundation
import Foundation

/// Every sound in the app is synthesised at runtime from PCM buffers.
///
/// That keeps the binary tiny, removes any licensing question, and — more usefully — lets
/// the correct-answer tone pitch shift with the streak, so a combo is audible as well as
/// visible. Silence on a missing audio file is a bug class this avoids entirely.
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    /// The graph is pinned to one explicit format rather than negotiated with the output
    /// hardware. Negotiation means the node's output format can change once the engine
    /// starts, and `scheduleBuffer` raises an *uncatchable* Objective-C exception when a
    /// buffer does not match it exactly. Fixing the format at both ends removes that
    /// entire class of crash.
    private static let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isRunning = false
    private var isStarting = false
    /// False when the audio graph could not be built or the platform has no output
    /// device. Once that is known, no further attempts are made: `scheduleBuffer` raises
    /// an Objective-C exception rather than returning an error, so it must never be
    /// reached on an engine that is not actually running.
    private var isGraphUsable = false

    var isEnabled = true {
        didSet { if self.isEnabled { self.startIfNeeded() } }
    }

    private init() {
        engine.attach(player)
        guard let format = Self.format else {
            self.isGraphUsable = false
            return
        }
        self.isGraphUsable = (try? engine.connectNode(player, to: engine.mainMixerNode, format: format)) != nil

        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }
    }

    /// Moves AVAudioSession configuration off the main thread to eliminate Xcode
    /// Thread Performance Checker "AVAudioSession Hang Risk" warnings and UI stutters.
    nonisolated private static func configureSessionInBackground() {
        let session = AVAudioSession.sharedInstance()
        // `.ambient` means a puzzle game's audio ducks politely under music instead of
        // interrupting it, which is what players expect.
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    func prepare() {
        self.startIfNeeded()
    }

    func startIfNeeded() {
        guard !self.isRunning, !self.isStarting, self.isGraphUsable, self.isEnabled else { return }
        self.isStarting = true

        Task.detached(priority: .userInitiated) { [weak self] in
            Self.configureSessionInBackground()

            await MainActor.run { [weak self] in
                guard let self else { return }
                defer { self.isStarting = false }
                guard !self.isRunning, self.isGraphUsable, self.isEnabled else { return }

                do {
                    if !self.engine.isRunning {
                        try self.engine.start()
                    }
                    if !self.player.isPlaying {
                        if (try? self.player.playAudio()) == nil {
                            self.player.play()
                        }
                    }
                    self.isRunning = self.engine.isRunning && self.player.isPlaying
                } catch {
                    self.isRunning = false
                }
            }
        }
    }

    private func handleConfigurationChange() {
        self.isRunning = false
        if self.isEnabled {
            self.startIfNeeded()
        }
    }

    // MARK: - Cues

    func correct(streak: Int) {
        let base = 523.25  // C5
        let step = Double(min(streak, 6)) * 2.0  // semitones per combo level
        self.play(self.arppeggio(root: base * pow(2, step / 12.0), notes: 3, noteLength: 0.075, decay: 0.30))
    }

    func wrong() {
        self.play(self.tonePair(frequency: 196.0, second: 155.56, length: 0.20, decay: 0.55, buzz: true))
    }

    func levelCleared() {
        let root = 392.0
        self.play(self.arppeggio(root: root, notes: 5, noteLength: 0.10, decay: 0.55, ascending: true))
    }

    func selection() {
        self.play(self.tone(frequency: 880, length: 0.045, decay: 0.20))
    }

    func hint() {
        self.play(self.tonePair(frequency: 659.25, second: 987.77, length: 0.14, decay: 0.35))
    }

    func countdownTick(urgent: Bool) {
        self.play(self.tone(frequency: urgent ? 1320 : 990, length: 0.05, decay: 0.30))
    }

    // MARK: - Synthesis

    private func arppeggio(
        root: Double, notes: Int, noteLength: Double, decay: Double, ascending: Bool = true
    ) -> AVAudioPCMBuffer? {
        guard let format = Self.format else { return nil }
        let sampleRate = format.sampleRate
        guard sampleRate > 0 else { return nil }
        let total = noteLength * Double(notes)
        let frames = AVAudioFrameCount(total * sampleRate)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames

        // Gentle 5th-based intervals so an arpeggio sounds like a reward rather than a
        // scale run.
        let intervals: [Double] = ascending ? [1.0, 1.26, 1.5, 1.89, 2.0] : [1.5, 1.26, 1.0, 1.26, 1.5]

        for frame in 0..<Int(frames) {
            let time = Double(frame) / sampleRate
            let noteIndex = min(Int(time / noteLength), notes - 1)
            let localTime = time - Double(noteIndex) * noteLength
            let frequency = root * intervals[noteIndex % intervals.count]
            let envelope = exp(-localTime / decay) * (1.0 - exp(-localTime / 0.006))
            channel[frame] = Float(sin(2 * .pi * frequency * time) * envelope * 0.30)
        }
        return buffer
    }

    private func tonePair(
        frequency: Double, second: Double, length: Double, decay: Double, buzz: Bool = false
    ) -> AVAudioPCMBuffer? {
        guard let format = Self.format else { return nil }
        let sampleRate = format.sampleRate
        guard sampleRate > 0 else { return nil }
        let frames = AVAudioFrameCount(length * sampleRate)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames

        for frame in 0..<Int(frames) {
            let time = Double(frame) / sampleRate
            let progress = time / length
            let current = progress < 0.5 ? frequency : second
            let local = progress < 0.5 ? time : time - length / 2
            let envelope = exp(-local / decay) * (1.0 - exp(-time / 0.008))
            // The wrong-answer tone uses a sawtooth so it is audibly harsher than the
            // rounded sines used everywhere else.
            let wave = buzz
                ? (2.0 * ((time * current).truncatingRemainder(dividingBy: 1.0)) - 1.0)
                : sin(2 * .pi * current * time)
            channel[frame] = Float(wave * envelope * 0.26)
        }
        return buffer
    }

    private func tone(frequency: Double, length: Double, decay: Double) -> AVAudioPCMBuffer? {
        self.tonePair(frequency: frequency, second: frequency, length: length, decay: decay)
    }

    private func play(_ buffer: AVAudioPCMBuffer?) {
        guard self.isEnabled, let buffer else { return }
        self.startIfNeeded()
        // Every condition is re-checked immediately before scheduling. `scheduleBuffer`
        // raises an uncaught Objective-C exception when the node is not playing, so this
        // guard is load-bearing rather than defensive.
        self.player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !self.player.isPlaying {
            if (try? self.player.playAudio()) == nil {
                self.player.play()
            }
        }
    }
}