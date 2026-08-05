import SwiftUI

struct TraeMenuBarUsage: View {
    let value: String
    let remainingPercent: Double?
    let resetEmphasis: CGFloat

    init(
        value: String,
        remainingPercent: Double?,
        resetEmphasis: CGFloat = 0
    ) {
        self.value = value
        self.remainingPercent = remainingPercent
        self.resetEmphasis = resetEmphasis
    }

    var body: some View {
        HStack(spacing: 1.5) {
            Text(self.value)
                .font(TraeTheme.Typography.menuMetric(size: self.metricFontSize))
                .foregroundStyle(
                    self.isResetEmphasized
                        ? TraeTheme.Palette.accentTeal
                        : self.isLowRemaining
                            ? TraeTheme.Palette.statusError
                            : TraeTheme.Palette.textHover
                )
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 1)

            Text("Codex left")
                .font(TraeTheme.Typography.menuLabel)
                .foregroundStyle(TraeTheme.Palette.text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(TraeTheme.Palette.overlay3)

                    Capsule()
                        .fill(
                            self.isLowRemaining
                                ? TraeTheme.Palette.statusError
                                : TraeTheme.Palette.accentTeal
                        )
                        .frame(height: geometry.size.height * self.progress)
                }
            }
            .frame(width: 1.5, height: 16)
        }
        .padding(.horizontal, TraeTheme.Spacing.compact)
        .frame(width: 80, height: 22)
        .background(TraeTheme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: TraeTheme.Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: TraeTheme.Radius.medium)
                .stroke(TraeTheme.Palette.border2, lineWidth: 0.5)
        }
        .environment(\.colorScheme, .dark)
    }

    private var progress: CGFloat {
        guard let remainingPercent else { return 0 }
        return min(max(remainingPercent / 100, 0), 1)
    }

    var isLowRemaining: Bool {
        guard let remainingPercent else { return false }
        return remainingPercent < 10
    }

    var isResetEmphasized: Bool {
        self.resetEmphasis > 0
    }

    var metricFontSize: CGFloat {
        let emphasis = min(max(self.resetEmphasis, 0), 1)
        let normal = TraeTheme.Typography.menuMetricSize
        let maximum = TraeTheme.Typography.resetMetricSize
        return normal + (maximum - normal) * emphasis
    }
}
