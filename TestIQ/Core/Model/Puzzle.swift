import Foundation

// MARK: - Shape vocabulary

/// A declarative description of a visual element. Every spatial, matrix and odd-one-out
/// puzzle in the game is generated from these, which means the entire visual puzzle bank
/// costs a few kilobytes of code instead of shipping bitmaps — and it scales with
/// difficulty for free.
public struct ShapeSpec: Codable, Sendable, Hashable {
    public enum Shape: String, Codable, CaseIterable, Sendable {
        case circle, square, triangle, diamond, pentagon, hexagon, star, cross, ring, bar, arrow, crescent
    }

    public enum Fill: String, Codable, CaseIterable, Sendable {
        case solid, hollow, dotted, striped, halfTop, halfBottom
    }

    public enum Arrangement: String, Codable, CaseIterable, Sendable {
        /// One shape, centred.
        case single
        /// `count` shapes in a horizontal row.
        case row
        /// `count` shapes evenly spaced around a circle.
        case ring
        /// `count` shapes packed into a centred cluster (up to 3×3).
        case cluster
    }

    public var shape: Shape
    public var fill: Fill
    /// Degrees, always a multiple of 45 so the renderer stays crisp.
    public var rotation: Int
    /// `-1` mirrors the shape horizontally about its own centre; `1` leaves it alone.
    public var handed: Int
    public var arrangement: Arrangement
    /// How many shapes the arrangement draws. Clamped to 1...9 by the renderer.
    public var count: Int

    public init(
        shape: Shape = .circle,
        fill: Fill = .solid,
        rotation: Int = 0,
        handed: Int = 1,
        arrangement: Arrangement = .single,
        count: Int = 1
    ) {
        self.shape = shape
        self.fill = fill
        self.rotation = ((rotation % 360) + 360) % 360
        self.handed = handed < 0 ? -1 : 1
        self.arrangement = arrangement
        self.count = max(1, min(count, 9))
    }

    // MARK: Attribute mutation

    public func with(shape: Shape? = nil, fill: Fill? = nil, rotation: Int? = nil,
                      handed: Int? = nil, arrangement: Arrangement? = nil, count: Int? = nil) -> ShapeSpec {
        ShapeSpec(
            shape: shape ?? self.shape,
            fill: fill ?? self.fill,
            rotation: rotation ?? self.rotation,
            handed: handed ?? self.handed,
            arrangement: arrangement ?? self.arrangement,
            count: count ?? self.count
        )
    }

    /// Attribute count deliberately changed relative to `other`. Used to build matrix
    /// distractors that differ from the answer in exactly one respect, so a wrong choice
    /// is always informative rather than obviously wrong.
    public func differingAttributes(from other: ShapeSpec) -> Int {
        var count = 0
        if self.shape != other.shape { count += 1 }
        if self.fill != other.fill { count += 1 }
        if self.rotation != other.rotation { count += 1 }
        if self.handed != other.handed { count += 1 }
        if self.arrangement != other.arrangement { count += 1 }
        if self.count != other.count { count += 1 }
        return count
    }

    public static func random(generator: inout SeededGenerator, shapes: [Shape] = Shape.allCases,
                              fills: [Fill] = Fill.allCases,
                              arrangements: [Arrangement] = Arrangement.allCases) -> ShapeSpec {
        ShapeSpec(
            shape: generator.pick(shapes),
            fill: generator.pick(fills),
            rotation: generator.pick([0, 45, 90, 135, 180, 225, 270, 315]),
            handed: 1,
            arrangement: generator.pick(arrangements),
            count: generator.nextInt(in: 1...4)
        )
    }
}

// MARK: - Matrix

public struct MatrixSpec: Codable, Sendable, Hashable {
    public enum Rule: String, Codable, Sendable {
        /// Each row steps the shape attribute by a constant.
        case rowProgress
        /// Each column steps the attribute.
        case columnProgress
        /// Rows step the shape, columns step the fill.
        case rowAndColumn
        /// Cells alternate between two specs down each row.
        case alternating
    }

    /// Row-major cells, `nil` marking the one the player must fill in. Count may be any
    /// perfect square — 9 for a reasoning matrix, 16 or 25 for an unfolded sheet.
    public var cells: [ShapeSpec?]
    public var rule: Rule

    public init(cells: [ShapeSpec?], rule: Rule) {
        precondition(!cells.isEmpty, "a matrix always has cells")
        self.cells = cells
        self.rule = rule
    }

    public var missingIndex: Int { self.cells.firstIndex(where: { $0 == nil }) ?? 8 }
    public var missingRow: Int { self.missingIndex / 3 }
    public var missingColumn: Int { self.missingIndex % 3 }
}

// MARK: - Memory

public struct MemorySpec: Codable, Sendable, Hashable {
    public var columns: Int
    public var rows: Int
    /// Indices flashed one after another, for `memorySequence`.
    public var sequence: [Int]
    /// Indices lit simultaneously, for `gridRecall`.
    public var lit: [Int]

    public init(columns: Int, rows: Int, sequence: [Int] = [], lit: [Int] = []) {
        self.columns = columns
        self.rows = rows
        self.sequence = sequence
        self.lit = lit
    }

    public var cellCount: Int { self.rows * self.columns }
    public var isValid: Bool {
        guard self.rows > 0, self.columns > 0, self.cellCount <= 25 else { return false }
        let indices = self.sequence + self.lit
        return indices.allSatisfy { $0 >= 0 && $0 < self.cellCount }
    }
}

// MARK: - Stimulus

/// What the puzzle shows above the answers. Rendering is driven purely from this value,
/// so adding a puzzle family never requires touching the puzzle view.
public enum PuzzleStimulus: Sendable, Hashable {
    case none
    case text(String)
    /// A run of numbers, optionally ending in a placeholder.
    case numbers([Int])
    case word(String)
    case shape(ShapeSpec)
    case shapes([ShapeSpec])
    case matrix(MatrixSpec)
    case memory(MemorySpec)
}

// MARK: - Options

public struct PuzzleOption: Identifiable, Sendable, Hashable {
    public enum Graphic: Sendable, Hashable {
        case none
        case shape(ShapeSpec)
        case grid(MatrixSpec)
        case word(String)
        case number(Int)
    }

    public let id: String
    public let title: String
    public let graphic: Graphic

    public init(id: String, title: String = "", graphic: Graphic = .none) {
        self.id = id
        self.title = title
        self.graphic = graphic
    }
}

// MARK: - Answers

public enum PuzzleAnswer: Sendable, Hashable {
    case optionIndex(Int)
    case tapSequence([Int])
    case ordering([Int])
    case word(String)
}

// MARK: - Puzzle

public struct Puzzle: Identifiable, Sendable, Hashable {
    public let id: String
    public let kind: PuzzleKind
    /// Item difficulty on the latent ability scale (≈2.8 is average). This is the only
    /// difficulty signal the scoring engine sees, so every generator must place its
    /// items on this scale consistently.
    public let theta: Double
    public let prompt: String
    public let subtitle: String?
    public let stimulus: PuzzleStimulus
    public let options: [PuzzleOption]
    public let answer: PuzzleAnswer
    /// A scaffolded clue. Never the answer itself.
    public let hint: String
    public let timeLimit: TimeInterval
    /// Narrow classification used to detect clusters of specific mistakes, e.g.
    /// `alternating-difference` or `mirror-handedness`.
    public let skillTag: String
    /// Scrambled letter tiles for the `scramble` archetype. Empty for every other kind.
    public let tiles: [String]
    /// Item labels for the `order` archetype, already in a deliberately wrong order.
    /// Empty for every other kind.
    public let orderLabels: [String]

    public var domain: CognitiveDomain { self.kind.domain }
    public var archetype: PuzzleArchetype { self.kind.archetype }

    public init(
        id: String,
        kind: PuzzleKind,
        theta: Double,
        prompt: String,
        subtitle: String? = nil,
        stimulus: PuzzleStimulus = .none,
        options: [PuzzleOption] = [],
        answer: PuzzleAnswer,
        hint: String,
        timeLimit: TimeInterval,
        skillTag: String,
        tiles: [String] = [],
        orderLabels: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.theta = theta
        self.prompt = prompt
        self.subtitle = subtitle
        self.stimulus = stimulus
        self.options = options
        self.answer = answer
        self.hint = hint
        self.timeLimit = timeLimit
        self.skillTag = skillTag
        self.tiles = tiles
        self.orderLabels = orderLabels
    }
}