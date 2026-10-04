import SwiftUI

/// The depleting clock.
///
/// Three channels of urgency — colour, a symbol and a pulse — so the warning is legible
/// without relying on red/green discrimination or on motion being available.
struct TimerRing: View {
    let fraction: Double
    let seconds: TimeInterval
    var tint: Color = Theme.accent
    var size: CGFloat = 52

    private var urgent: Bool { self.fraction < 0.2 }
    private var warning: Bool { self.fraction < 0.4 }

    private var ringColor: Color {
        if self.urgent { return Theme.incorrect }
        if self.warning { return Theme.hint }
        return self.tint
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 5)

            Circle()
                .trim(from: 0, to: max(0.001, self.fraction))
                .stroke(self.ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.enabled ? .linear(duration: 0.1) : nil, value: self.fraction)

            Text(String(Int(ceil(self.seconds))))
                .font(.mono(17, weight: .bold))
                .foregroundStyle(self.urgent ? self.ringColor : Theme.textPrimary)
                .contentTransition(.numericText(countsDown: true))
        }
        .frame(width: self.size, height: self.size)
        .animation(Motion.enabled ? Motion.snappy : nil, value: self.urgent)
        .accessibilityElement()
        .accessibilityLabel("Time remaining")
        .accessibilityValue("\(Int(ceil(self.seconds))) seconds")
    }
}

/// Progress pips, the combo multiplier, and the hint charge.
struct HUDView: View {
    let level: LevelDefinition
    let model: GameViewModel
    var accent: Color

    var body: some View {
        HStack(spacing: 12) {
            Button {
                HapticsEngine.shared.tap()
                model.stop()
                NotificationCenter.default.post(name: .quitRun, object: nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: Theme.Metrics.minTarget, height: Theme.Metrics.minTarget)
                    .background { Circle().fill(Theme.surface) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Leave this floor")

            VStack(spacing: 6) {
                HStack {
                    Text("FLOOR \(self.level.id)")
                        .font(.app(.caption2, size: 11, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(self.accent)
                    Spacer()
                    Text("\(self.model.index + 1)/\(self.model.puzzles.count)")
                        .font(.mono(12, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .accessibilityLabel(self.model.summaryLine)
                }

                ProgressTrack(progress: self.model.progress, tint: self.accent)

                Text("\(self.model.score.formatted()) PTS")
                    .font(.mono(14, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.numericText())
                    .accessibilityLabel("Score: \(self.model.score) points")

                if self.model.streak >= 2 {
                    ComboBadge(streak: self.model.streak, multiplier: self.model.comboMultiplier)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            TimerRing(
                fraction: self.model.timeFraction,
                seconds: self.model.timeRemaining,
                tint: self.accent
            )

            Button {
                model.useHint()
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: self.model.showHint ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: 15, weight: .bold))
                    Text("\(self.model.hintsRemaining)")
                        .font(.mono(11, weight: .bold))
                }
                .foregroundStyle(self.model.hintsRemaining > 0 ? Theme.hint : Theme.textTertiary)
                .frame(width: Theme.Metrics.minTarget, height: Theme.Metrics.minTarget)
                .background { Circle().fill(Theme.surface) }
            }
            .buttonStyle(.plain)
            .disabled(self.model.hintsRemaining == 0 || self.model.showHint || self.model.phase != .awaitingAnswer)
            .opacity(self.model.hintsRemaining == 0 ? 0.5 : 1)
            .accessibilityLabel("Use a hint")
            .accessibilityValue("\(self.model.hintsRemaining) remaining")
        }
        .animation(Motion.enabled ? Motion.snappy : nil, value: self.model.streak)
        .animation(Motion.enabled ? Motion.snappy : nil, value: self.model.showHint)
    }
}

private struct ProgressTrack: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(self.tint)
                    .frame(width: max(4, proxy.size.width * self.progress))
            }
        }
        .frame(height: 5)
        .animation(Motion.enabled ? Motion.gentle : nil, value: self.progress)
        .accessibilityLabel("Progress through this floor")
        .accessibilityValue("\(Int(self.progress * 100)) percent")
    }
}

/// The combo indicator. Pitch of the correct-answer tone rises with this number, so a
/// streak is audible as well as visible.
struct ComboBadge: View {
    let streak: Int
    let multiplier: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11, weight: .bold))
            Text("×\(self.multiplier)")
                .font(.mono(13, weight: .heavy))
            Text("· \(self.streak) in a row")
                .font(.app(.caption2, size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .foregroundStyle(Theme.incorrect)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule().fill(Theme.incorrect.opacity(0.14))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(self.streak) correct in a row, multiplier times \(self.multiplier)")
    }
}

extension Notification.Name {
    static let quitRun = Notification.Name("quitRun")
}
