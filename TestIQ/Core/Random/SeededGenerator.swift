import Foundation

/// SplitMix64. A tiny, fast, fully deterministic generator so that every puzzle in the
/// game can be reproduced exactly from a seed. Reproducibility is what makes the
/// generators testable and what lets a level be replayed identically after a crash.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public init(seed: String) {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        self.state = hash
    }

    public mutating func next() -> UInt64 {
        self.state = self.state &+ 0x9E37_79B9_7F4A_7C15
        var z = self.state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    // MARK: - Convenience

    /// Uniform in `0..<upperBound`.
    public mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound must be positive")
        return Int(self.next() % UInt64(upperBound))
    }

    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + self.nextInt(upperBound: range.count)
    }

    public mutating func nextInt(in range: Range<Int>) -> Int {
        range.lowerBound + self.nextInt(upperBound: range.count)
    }

    public mutating func nextBool(probability: Double = 0.5) -> Bool {
        Double(self.next() >> 11) * (1.0 / 9_007_199_254_740_992.0) < probability
    }

    public mutating func nextDouble(in range: ClosedRange<Double> = 0...1) -> Double {
        let unit = Double(self.next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    public mutating func pick<T>(_ items: [T]) -> T {
        items[self.nextInt(upperBound: items.count)]
    }

    /// Fisher–Yates. Returns a new array; does not mutate the input.
    public mutating func shuffled<T>(_ items: [T]) -> [T] {
        var result = items
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, to: 0, by: -1) {
            let swapIndex = self.nextInt(upperBound: index + 1)
            result.swapAt(index, swapIndex)
        }
        return result
    }

    /// Picks `count` distinct elements, preserving no particular order.
    public mutating func sample<T>(_ items: [T], count: Int) -> [T] {
        self.shuffled(items).prefix(max(0, min(count, items.count))).map { $0 }
    }
}