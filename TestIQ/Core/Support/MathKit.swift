import Foundation

/// Small arithmetic helpers shared by the quantity generators. Kept here so the
/// generators read as puzzle descriptions rather than number theory.
public enum MathKit {
    public static func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a)
        var y = abs(b)
        while y != 0 {
            (x, y) = (y, x % y)
        }
        return x == 0 ? 1 : x
    }

    public static func lcm(_ a: Int, _ b: Int) -> Int {
        let divisor = gcd(a, b)
        return divisor == 0 ? 0 : abs(a * b) / divisor
    }

    /// Reduces a ratio to lowest terms.
    public static func simplify(_ numerator: Int, _ denominator: Int) -> (Int, Int) {
        let divisor = gcd(numerator, denominator)
        guard divisor > 0 else { return (numerator, denominator) }
        return (numerator / divisor, denominator / divisor)
    }

    /// Nearest multiple of `step` to `value`, used to build solvable work-rate problems.
    public static func roundedMultiple(of step: Int, near value: Int) -> Int {
        guard step > 0 else { return value }
        return Int((Double(value) / Double(step)).rounded()) * step
    }

    public static func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
        min(max(value, lower), upper)
    }

    /// Standard normal CDF (Abramowitz & Stegun 7.1.26 applied to erf). Accurate to
    /// ~1e-7, which is far tighter than anything a percentile badge will ever display.
    public static func normalCDF(_ z: Double) -> Double {
        let sign = z < 0 ? -1.0 : 1.0
        let x = abs(z) / 2.0.squareRoot()
        let t = 1.0 / (1.0 + 0.3275911 * x)
        let y = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t
            - 0.284496736) * t + 0.254829592) * t * exp(-x * x)
        return 0.5 * (1.0 + sign * y)
    }
}