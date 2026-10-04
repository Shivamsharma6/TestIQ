import SwiftUI

/// A rounded translucent panel. The workhorse container for the whole app.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 18
    var tint: Color = .clear
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(self.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.Metrics.corner, style: .continuous)
                    .fill(Theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Metrics.corner, style: .continuous)
                            .fill(self.tint.opacity(0.10))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Metrics.corner, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }
            }
    }
}

/// The primary call to action. One per screen, always full width on compact devices.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var tint: Color = Theme.accent
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            guard self.isEnabled else { return }
            HapticsEngine.shared.tap()
            SoundEngine.shared.selection()
            self.action()
        }) {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage) }
                Text(self.title).font(.app(.headline, size: 17, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .frame(minHeight: 54)
            .foregroundStyle(self.isEnabled ? Color.black.opacity(0.85) : Theme.textTertiary)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(self.isEnabled ? self.tint : Theme.surfaceRaised)
            }
            .scaleEffect(self.isPressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!self.isEnabled)
        .animation(Motion.enabled ? Motion.snappy : nil, value: self.isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in self.isPressed = true }
                .onEnded { _ in self.isPressed = false }
        )
        .frame(minHeight: Theme.Metrics.minTarget)
        .accessibilityAddTraits(.isButton)
    }
}

/// A secondary, lower-emphasis action.
struct QuietButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button {
            HapticsEngine.shared.tap()
            self.action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(self.title).font(.app(.subheadline, size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(minHeight: Theme.Metrics.minTarget)
            .foregroundStyle(Theme.textSecondary)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

/// A labelled statistic.
struct StatTile: View {
    let value: String
    let label: String
    var tint: Color = Theme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(self.value)
                .font(.mono(26, weight: .bold))
                .foregroundStyle(self.tint)
                .contentTransition(.numericText())
            Text(self.label)
                .font(.app(.caption, size: 12, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(self.label): \(self.value)")
    }
}

/// Zero-to-three stars. Used on level nodes and in results, so the visual vocabulary is
/// consistent between the map and the summary.
struct StarRating: View {
    let stars: Int
    var total: Int = 3
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<self.total, id: \.self) { index in
                Image(systemName: index < self.stars ? "star.fill" : "star")
                    .font(.system(size: self.size, weight: .semibold))
                    .foregroundStyle(index < self.stars ? Theme.hint : Theme.textTertiary.opacity(0.4))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(self.stars) of \(self.total) stars")
    }
}

/// Section heading used across the report and level screens.
struct SectionHeading: View {
    let title: String
    var subtitle: String?
    var symbol: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
                Text(self.title)
                    .font(.app(.title3, size: 19, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.app(.subheadline, size: 13, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
