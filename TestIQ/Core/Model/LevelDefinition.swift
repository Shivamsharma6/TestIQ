import Foundation

/// A single floor on the ascent path.
public struct LevelDefinition: Identifiable, Sendable, Hashable {
    public let id: Int
    public let name: String
    /// Short line shown on the level node and the intro card.
    public let tagline: String
    public let domain: CognitiveDomain
    public let puzzleKinds: [PuzzleKind]
    public let itemCount: Int
    public let duration: TimeInterval
    public let hintCharges: Int
    /// θ of the first item.
    public let openingTheta: Double
    /// θ of the last item. Always ≥ `openingTheta`.
    public let closingTheta: Double
    /// The blend of puzzle kinds; `mixed` and `zenith` also draw from every domain.
    public let isAdaptive: Bool
    public let accentName: String

    public init(
        id: Int,
        name: String,
        tagline: String,
        domain: CognitiveDomain,
        puzzleKinds: [PuzzleKind],
        itemCount: Int,
        duration: TimeInterval,
        hintCharges: Int,
        openingTheta: Double,
        closingTheta: Double,
        isAdaptive: Bool = false,
        accentName: String = "indigo"
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.domain = domain
        self.puzzleKinds = puzzleKinds
        self.itemCount = itemCount
        self.duration = duration
        self.hintCharges = hintCharges
        self.openingTheta = openingTheta
        self.closingTheta = closingTheta
        self.isAdaptive = isAdaptive
        self.accentName = accentName
    }

    /// Seconds allowed per item, with the remainder reserved so the last item is never
    /// starved by the earlier ones.
    public var perItemLimit: TimeInterval {
        max(8, self.duration / Double(self.itemCount))
    }

    /// 0–1 target required for the top star, derived from how demanding the floor is.
    public var starGate: Double {
        0.60 + Double(self.id - 1) * 0.02
    }
}

/// The ten floors. Ordered, immutable, and the single source of truth for progression.
public enum LevelCatalog {
    public static let all: [LevelDefinition] = [
        LevelDefinition(
            id: 1,
            name: "First Steps",
            tagline: "Find the rhythm",
            domain: .pattern,
            puzzleKinds: [.sequence, .oddOneOut],
            itemCount: 5,
            duration: 90,
            hintCharges: 3,
            openingTheta: 1.0,
            closingTheta: 2.0,
            accentName: "mint"
        ),
        LevelDefinition(
            id: 2,
            name: "Number Trail",
            tagline: "Follow the numbers",
            domain: .quantity,
            puzzleKinds: [.ratio, .percentage, .arithmetic],
            itemCount: 6,
            duration: 100,
            hintCharges: 3,
            openingTheta: 1.2,
            closingTheta: 2.6,
            accentName: "sky"
        ),
        LevelDefinition(
            id: 3,
            name: "Word Vault",
            tagline: "Letters obey logic",
            domain: .verbal,
            puzzleKinds: [.anagram, .letterRelation, .oddOneOut],
            itemCount: 6,
            duration: 110,
            hintCharges: 3,
            openingTheta: 1.2,
            closingTheta: 2.8,
            accentName: "violet"
        ),
        LevelDefinition(
            id: 4,
            name: "Logic Lab",
            tagline: "Everything is constrained",
            domain: .logic,
            puzzleKinds: [.truthLiar, .ordering, .truthLiar],
            itemCount: 7,
            duration: 130,
            hintCharges: 2,
            openingTheta: 1.4,
            closingTheta: 3.2,
            accentName: "amber"
        ),
        LevelDefinition(
            id: 5,
            name: "Memory Vault",
            tagline: "Hold it, then let it go",
            domain: .memory,
            puzzleKinds: [.memorySequence, .gridRecall],
            itemCount: 7,
            duration: 120,
            hintCharges: 2,
            openingTheta: 1.4,
            closingTheta: 3.2,
            accentName: "coral"
        ),
        LevelDefinition(
            id: 6,
            name: "Mind's Eye",
            tagline: "Turn it in your head",
            domain: .spatial,
            puzzleKinds: [.rotation, .mirrorImage, .spatialCount, .foldedHoles],
            itemCount: 7,
            duration: 130,
            hintCharges: 2,
            openingTheta: 1.5,
            closingTheta: 3.4,
            accentName: "teal"
        ),
        LevelDefinition(
            id: 7,
            name: "Pattern Matrix",
            tagline: "Deduce the hidden rule",
            domain: .abstract,
            puzzleKinds: [.matrix, .sequence],
            itemCount: 8,
            duration: 150,
            hintCharges: 2,
            openingTheta: 1.6,
            closingTheta: 3.8,
            accentName: "indigo"
        ),
        LevelDefinition(
            id: 8,
            name: "Numbers Lab",
            tagline: "Rates, ratios, chances",
            domain: .quantity,
            puzzleKinds: [.rate, .probability, .percentage, .ratio],
            itemCount: 8,
            duration: 160,
            hintCharges: 2,
            openingTheta: 1.8,
            closingTheta: 4.2,
            accentName: "blue"
        ),
        LevelDefinition(
            id: 9,
            name: "Mixed Cortex",
            tagline: "It adapts to you",
            domain: .pattern,
            puzzleKinds: LevelCatalog.everyKind,
            itemCount: 9,
            duration: 170,
            hintCharges: 2,
            openingTheta: 2.0,
            closingTheta: 4.6,
            isAdaptive: true,
            accentName: "pink"
        ),
        LevelDefinition(
            id: 10,
            name: "The Zenith",
            tagline: "Everything, at once",
            domain: .abstract,
            puzzleKinds: LevelCatalog.everyKind,
            itemCount: 12,
            duration: 210,
            hintCharges: 3,
            openingTheta: 2.6,
            closingTheta: 5.2,
            isAdaptive: true,
            accentName: "gold"
        ),
    ]

    /// Every kind the generator layer can produce. Used by the adaptive floors.
    public static let everyKind: [PuzzleKind] = PuzzleKind.allCases

    public static var count: Int { all.count }

    public static func level(_ id: Int) -> LevelDefinition? {
        all.first { $0.id == id }
    }

    public static var finalLevelID: Int { all.last?.id ?? 10 }
}