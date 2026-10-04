import Foundation

/// Shared input rules used by gameplay and its interaction regressions.
public enum PuzzleInteraction {
    public enum Lesson: String, CaseIterable, Sendable {
        case choice, memorySequence, gridRecall, order, wordTiles

        public static func forKind(_ kind: PuzzleKind) -> Lesson {
            switch kind.archetype {
            case .choice: return .choice
            case .echo: return kind == .gridRecall ? .gridRecall : .memorySequence
            case .order: return .order
            case .scramble: return .wordTiles
            }
        }
    }

    public struct MemoryTap: Equatable {
        public let indices: [Int]
        public let shouldSubmit: Bool
    }

    public static func memoryTap(_ index: Int, current: [Int], expected: [Int], gridRecall: Bool) -> MemoryTap {
        guard !expected.isEmpty, current.count < expected.count,
              !gridRecall || !current.contains(index) else {
            return MemoryTap(indices: current, shouldSubmit: false)
        }
        let next = current + [index]
        let submit = next.count == expected.count || (!gridRecall && next != Array(expected.prefix(next.count)))
        return MemoryTap(indices: next, shouldSubmit: submit)
    }

    public static func memoryMatches(_ current: [Int], expected: [Int], gridRecall: Bool) -> Bool {
        if gridRecall {
            return current.count == expected.count && Set(current) == Set(expected)
        }
        return current == expected
    }
}

/// Tile identity matters when the bank contains the same letter more than once.
public struct WordTileDraft: Equatable {
    public private(set) var indices: [Int] = []
    public init() {}

    public mutating func append(_ index: Int, tiles: [String]) {
        guard tiles.indices.contains(index), !indices.contains(index) else { return }
        indices.append(index)
    }

    public mutating func undo(tiles: [String]) {
        _ = indices.popLast()
    }

    public func letters(in tiles: [String]) -> [String] { indices.map { tiles[$0] } }
}
