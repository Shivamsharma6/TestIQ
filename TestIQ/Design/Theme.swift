import SwiftUI

/// Shared arcade palette. Correctness also uses a symbol and a written label, so a
/// player's result never depends on distinguishing two colours.
enum Theme {
    // MARK: - Surfaces

    static let background = Color(red: 0.047, green: 0.043, blue: 0.075)
    static let surface = Color(red: 0.102, green: 0.094, blue: 0.145)
    static let surfaceRaised = Color(red: 0.153, green: 0.137, blue: 0.212)
    static let stroke = Color.white.opacity(0.10)
    static let strokeStrong = Color.white.opacity(0.23)

    // MARK: - Text

    static let textPrimary = Color(red: 0.98, green: 0.98, blue: 1.00)
    static let textSecondary = Color(red: 0.77, green: 0.76, blue: 0.84)
    static let textTertiary = Color(red: 0.63, green: 0.62, blue: 0.71)

    // MARK: - Semantic

    static let lime = Color(red: 0.82, green: 1.00, blue: 0.36)
    static let violet = Color(red: 0.69, green: 0.57, blue: 1.00)
    static let correct = lime
    static let incorrect = Color(red: 1.00, green: 0.62, blue: 0.42)
    static let accent = lime
    static let hint = Color(red: 1.00, green: 0.84, blue: 0.43)

    // MARK: - Floor accents

    static func accent(named name: String) -> Color {
        switch name {
        case "mint": return self.lime
        case "sky": return Color(red: 0.43, green: 0.81, blue: 1.00)
        case "violet": return self.violet
        case "amber": return Color(red: 1.00, green: 0.77, blue: 0.38)
        case "coral": return Color(red: 1.00, green: 0.59, blue: 0.61)
        case "teal": return Color(red: 0.32, green: 0.91, blue: 0.86)
        case "indigo": return Color(red: 0.66, green: 0.65, blue: 1.00)
        case "blue": return Color(red: 0.44, green: 0.71, blue: 1.00)
        case "pink": return Color(red: 1.00, green: 0.58, blue: 0.83)
        case "gold": return self.hint
        default: return self.accent
        }
    }

    /// A continuous magnitude scale for practice charts.
    static func scale(for value: Double) -> Color {
        let t = max(0, min(1, value))
        return Color(red: 1.00 - 0.18 * t, green: 0.65 + 0.35 * t, blue: 0.42 - 0.06 * t)
    }

    // MARK: - Metrics

    enum Metrics {
        static let corner: CGFloat = 22
        static let cornerLarge: CGFloat = 30
        static let gutter: CGFloat = 20
        static let stackSpacing: CGFloat = 16
        static let minTarget: CGFloat = 44
    }
}

extension Font {
    static func app(_ style: Font.TextStyle, size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight)
            .leading(.standard)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}
