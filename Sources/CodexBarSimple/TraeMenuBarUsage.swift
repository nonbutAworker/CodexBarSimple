import SwiftUI

struct TraeMenuBarUsage: View {
    let value: String
    let remainingPercent: Double?
    let isLunaReserve: Bool
    let resetEmphasis: CGFloat
    let isResetScheduled: Bool

    init(
        value: String,
        remainingPercent: Double?,
        isLunaReserve: Bool = false,
        resetEmphasis: CGFloat = 0,
        isResetScheduled: Bool = false
    ) {
        self.value = value
        self.remainingPercent = remainingPercent
        self.isLunaReserve = isLunaReserve
        self.resetEmphasis = resetEmphasis
        self.isResetScheduled = isResetScheduled
    }

    var body: some View {
        HStack(spacing: 1.5) {
            if self.isLunaReserve {
                Image(systemName: "moon.fill")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(self.metricColor)
                    .frame(width: 8)
            }

            Text(self.value)
                .font(TraeTheme.Typography.menuMetric(size: self.metricFontSize))
                .foregroundStyle(self.metricColor)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 1)

            Text(self.isLunaReserve ? "Luna left" : "Codex left")
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
                            self.progressColor
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
                .strokeBorder(
                    self.isResetScheduled ? TraeTheme.Palette.statusWarning : TraeTheme.Palette.border2,
                    lineWidth: self.isResetScheduled ? 1.5 : 0.5)
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

    private var metricColor: Color {
        if self.isResetEmphasized {
            return TraeTheme.Palette.accentTeal
        }
        if self.isLowRemaining {
            return TraeTheme.Palette.statusError
        }
        if self.isLunaReserve {
            return TraeTheme.Palette.reserveGold
        }
        return TraeTheme.Palette.textHover
    }

    private var progressColor: Color {
        if self.isResetEmphasized {
            return TraeTheme.Palette.accentTeal
        }
        if self.isLowRemaining {
            return TraeTheme.Palette.statusError
        }
        return self.isLunaReserve
            ? TraeTheme.Palette.reserveGold
            : TraeTheme.Palette.accentTeal
    }

    var metricFontSize: CGFloat {
        let emphasis = min(max(self.resetEmphasis, 0), 1)
        let normal = TraeTheme.Typography.menuMetricSize
        let maximum = TraeTheme.Typography.resetMetricSize
        return normal + (maximum - normal) * emphasis
    }
}
