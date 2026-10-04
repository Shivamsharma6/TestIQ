import Foundation

/// The 19 puzzle families. Each one maps to exactly one `CognitiveDomain`, which is what
/// lets the scoring engine build a per-domain profile without the view layer passing any
/// classification around.
public enum PuzzleKind: String, Codable, CaseIterable, Sendable {
    // Pattern
    case sequence
    case oddOneOut
    // Verbal
    case anagram
    case letterRelation
    // Deduction
    case truthLiar
    case ordering
    // Working memory
    case memorySequence
    case gridRecall
    // Spatial
    case rotation
    case mirrorImage
    case foldedHoles
    case spatialCount
    // Abstract
    case matrix
    // Quantity
    case ratio
    case percentage
    case rate
    case probability
    case arithmetic

    /// How the player interacts with this puzzle.
    public var archetype: PuzzleArchetype {
        switch self {
        case .memorySequence, .gridRecall:
            return .echo
        case .ordering:
            return .order
        case .anagram:
            return .scramble
        default:
            return .choice
        }
    }

    /// The axis this puzzle contributes to.
    public var domain: CognitiveDomain {
        switch self {
        case .sequence, .oddOneOut:
            return .pattern
        case .anagram, .letterRelation:
            return .verbal
        case .truthLiar, .ordering:
            return .logic
        case .memorySequence, .gridRecall:
            return .memory
        case .rotation, .mirrorImage, .foldedHoles, .spatialCount:
            return .spatial
        case .matrix:
            return .abstract
        case .ratio, .percentage, .rate, .probability, .arithmetic:
            return .quantity
        }
    }

    /// A short human label used on the HUD and in the report's error breakdown.
    public var title: String {
        switch self {
        case .sequence: return "Number Sequence"
        case .oddOneOut: return "Odd One Out"
        case .anagram: return "Word Rebuild"
        case .letterRelation: return "Letter Algebra"
        case .truthLiar: return "Truth or Lie"
        case .ordering: return "Put In Order"
        case .memorySequence: return "Echo Sequence"
        case .gridRecall: return "Grid Recall"
        case .rotation: return "Mental Rotation"
        case .mirrorImage: return "Mirror Image"
        case .foldedHoles: return "Unfold The Paper"
        case .spatialCount: return "Count The Shapes"
        case .matrix: return "Pattern Matrix"
        case .ratio: return "Ratios"
        case .percentage: return "Percentages"
        case .rate: return "Work Rates"
        case .probability: return "Probability"
        case .arithmetic: return "Quick Maths"
        }
    }

    /// Item difficulty ceiling. Generators use this to place an item on the latent θ
    /// scale, so difficulty numbers across the whole bank are directly comparable.
    public var maxTheta: Double {
        switch self {
        case .sequence, .oddOneOut: return 4.6
        case .anagram, .letterRelation: return 4.4
        case .truthLiar, .ordering: return 4.8
        case .memorySequence: return 4.2
        case .gridRecall: return 4.0
        case .rotation, .mirrorImage: return 4.5
        case .foldedHoles: return 5.0
        case .spatialCount: return 4.0
        case .matrix: return 5.2
        case .ratio, .percentage: return 4.6
        case .rate, .probability: return 5.0
        case .arithmetic: return 3.2
        }
    }

    /// Floor on θ for this kind, so an easy variant of a hard kind never pretends to be
    /// a trivially easy item.
    public var minTheta: Double {
        switch self {
        case .memorySequence, .gridRecall: return 1.2
        case .arithmetic: return 1.0
        default: return 1.0
        }
    }
}

public enum PuzzleArchetype: String, Codable, Sendable {
    /// Pick exactly one option.
    case choice
    /// Reproduce a flashed sequence of taps.
    case echo
    /// Drag items into the correct order.
    case order
    /// Tap tiles to rebuild a target string.
    case scramble
}