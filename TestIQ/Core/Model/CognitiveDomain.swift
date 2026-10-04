import Foundation

/// The eight axes of the final brain profile. Seven are measured by puzzles that belong
/// to them; `speed` is derived from response latency across every item, which makes it a
/// genuine cross-cutting measurement rather than a duplicate of any one floor.
public enum CognitiveDomain: String, Codable, CaseIterable, Sendable, Identifiable {
    case pattern
    case verbal
    case logic
    case memory
    case spatial
    case abstract
    case quantity
    case speed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pattern: return "Pattern Recognition"
        case .verbal: return "Verbal Reasoning"
        case .logic: return "Logical Deduction"
        case .memory: return "Working Memory"
        case .spatial: return "Spatial Reasoning"
        case .abstract: return "Abstract Generalisation"
        case .quantity: return "Numerical Reasoning"
        case .speed: return "Attention & Speed"
        }
    }

    public var shortTitle: String {
        switch self {
        case .pattern: return "Patterns"
        case .verbal: return "Verbal"
        case .logic: return "Logic"
        case .memory: return "Memory"
        case .spatial: return "Spatial"
        case .abstract: return "Abstract"
        case .quantity: return "Numbers"
        case .speed: return "Speed"
        }
    }

    public var symbol: String {
        switch self {
        case .pattern: return "circle.grid.2x2"
        case .verbal: return "text.book.closed"
        case .logic: return "point.topleft.down.to.point.bottomright.curvepath"
        case .memory: return "brain.head.profile"
        case .spatial: return "cube.transparent"
        case .abstract: return "square.on.square.dashed"
        case .quantity: return "function"
        case .speed: return "gauge.with.dots.needle.33percent"
        }
    }

    /// One-line description used in the report so the player learns what the axis means.
    public var blurb: String {
        switch self {
        case .pattern: return "Spotting the rule that governs a run of items."
        case .verbal: return "Working with words, letters and their relationships."
        case .logic: return "Holding several constraints at once and eliminating."
        case .memory: return "Holding information in mind and reproducing it on demand."
        case .spatial: return "Mentally rotating, mirroring and folding shapes."
        case .abstract: return "Deduce a hidden rule from incomplete information."
        case .quantity: return "Numbers in motion — rates, ratios and probability."
        case .speed: return "How quickly and reliably you commit to an answer."
        }
    }

    /// Order used by the radar chart, chosen so adjacent axes are related.
    public static let radarOrder: [CognitiveDomain] = [
        .pattern, .abstract, .spatial, .memory, .verbal, .logic, .quantity, .speed,
    ]
}