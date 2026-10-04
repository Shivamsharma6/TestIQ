import SwiftUI

/// Motion tokens, plus one place that decides whether motion should happen at all.
///
/// Every animated view in the app reads `Motion.enabled` rather than checking
/// `accessibilityReduceMotion` itself, so honouring the system setting cannot be forgotten
/// in one screen and honoured in another.
enum Motion {
    /// `nil` until something has explicitly overridden the system setting (previews do).
    private static var reduceMotionOverride: Bool?

    static var enabled: Bool {
        if let reduceMotionOverride { return !reduceMotionOverride }
        return !UIAccessibility.isReduceMotionEnabled
    }

    static func setReduceMotion(_ value: Bool) {
        reduceMotionOverride = value
    }

    // MARK: - Springs

    static let gentle = Animation.spring(response: 0.35, dampingFraction: 0.82)
    static let snappy = Animation.spring(response: 0.24, dampingFraction: 0.72)
    static let bouncy = Animation.spring(response: 0.40, dampingFraction: 0.62)
    static let settle = Animation.spring(response: 0.55, dampingFraction: 0.85)

    // MARK: - Durations

    static let instant: TimeInterval = 0.12
    static let quick: TimeInterval = 0.25
    static let normal: TimeInterval = 0.45
    static let slow: TimeInterval = 0.9

    /// The animation to use, or `nil` when motion should be suppressed.
    static func animate(_ animation: Animation) -> Animation? {
        self.enabled ? animation : nil
    }
}

/// Fades and lifts a view in on first appearance.
///
/// Declared at file scope rather than inside the `View` extension below, because a
/// protocol extension cannot nest types.
private struct AppearInModifier: ViewModifier {
    @State private var shown = false
    let delay: TimeInterval

    func body(content: Content) -> some View {
        content
            .opacity(self.shown ? 1 : 0)
            .offset(y: self.shown ? 0 : 14)
            .onAppear {
                if self.delay > 0 || Motion.enabled {
                    withAnimation(Motion.settle.delay(self.delay)) { self.shown = true }
                } else {
                    self.shown = true
                }
            }
    }
}

extension View {
    /// Reveals content on a stagger. Collapses to an immediate appearance under
    /// Reduce Motion, so nothing is ever left invisible.
    func appearIn(_ delay: TimeInterval = 0) -> some View {
        self.modifier(AppearInModifier(delay: Motion.enabled ? delay : 0))
    }

    /// A soft, wide shadow that reads as elevation on a near-black background.
    func elevated(_ radius: CGFloat = 18, y: CGFloat = 8) -> some View {
        self.shadow(color: .black.opacity(0.45), radius: radius, x: 0, y: y)
    }
}