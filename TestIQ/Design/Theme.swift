import SwiftUI

/// The single source of truth for colour, type and spacing.
///
/// The palette is deliberately not built on red/green as a correctness signal: those two
/// are indistinguishable to the most common form of colour blindness. Correctness is
/// therefore always carried by three channels at once — colour, an SF Symbol, and motion.
enum Theme {
    // MARK: - Surfaces

    static let background = Color(red: 0.043, green: 0.055, blue: 0.098)
    static let surface = Color(red: 0.086, green: 0.102, blue: 0.161)
    static let surfaceRaised = Color(red: 0.125, green: 0.145, blue: 0.212)
    static let stroke = Color.white.opacity(0.10)
    static let strokeStrong = Color.white.opacity(0.20)

    // MARK: - Text

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.68)
    static let textTertiary = Color.white.opacity(0.42)

    // MARK: - Semantic

    /// Amber, not red, for "that was wrong". Distinct in hue *and* lightness from the
    /// success colour, and paired with an xmark symbol everywhere it appears.
    static let correct = Color(red: 0.35, green: 0.85, blue: 0.62)
    static let incorrect = Color(red: 1.00, green: 0.58, blue: 0.32)
    static let accent = Color(red: 0.55, green: 0.60, blue: 1.00)
    static let hint = Color(red: 1.00, green: 0.82, blue: 0.42)

    // MARK: - Floor accents

    static func accent(named name: String) -> Color {
        switch name {
        case "mint": return Color(red: 0.36, green: 0.90, blue: 0.72)
        case "sky": return Color(red: 0.40, green: 0.75, blue: 1.00)
        case "violet": return Color(red: 0.68, green: 0.56, blue: 1.00)
        case "amber": return Color(red: 1.00, green: 0.76, blue: 0.38)
        case "coral": return Color(red: 1.00, green: 0.55, blue: 0.52)
        case "teal": return Color(red: 0.32, green: 0.88, blue: 0.86)
        case "indigo": return Color(red: 0.52, green: 0.58, blue: 1.00)
        case "blue": return Color(red: 0.35, green: 0.62, blue: 1.00)
        case "pink": return Color(red: 1.00, green: 0.52, blue: 0.78)
        case "gold": return Color(red: 1.00, green: 0.83, blue: 0.35)
        default: return self.accent
        }
    }

    /// Colour for a 0–1 value on the report's domain bars. Deliberately a single-hue
    /// ramp from amber to mint so a bar's colour encodes magnitude, not category.
    static func scale(for value: Double) -> Color {
        let t = max(0, min(1, value))
        return Color(
            red: 0.95 - 0.55 * t,
            green: 0.62 + 0.22 * t,
            blue: 0.35 + 0.30 * t
        )
    }

    // MARK: - Metrics

    enum Metrics {
        static let corner: CGFloat = 20
        static let cornerLarge: CGFloat = 28
        static let gutter: CGFloat = 20
        static let stackSpacing: CGFloat = 14
        /// Apple's minimum comfortable hit target. Enforced on every control.
        static let minTarget: CGFloat = 44
    }
}

extension Font {
    static func app(_ style: Font.TextStyle, size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
            .leading(.standard)
    }

    /// Tabular figures keep counting timers from jittering as digits change width.
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}