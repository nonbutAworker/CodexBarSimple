import SwiftUI

struct TraeMenuBarUsage: View {
    let value: String
    let remainingPercent: Double?
    let isLunaReserve: Bool
    let resetEmphasis: CGFloat
    let isResetScheduled: Bool
    let bellRotation: Double

    init(
        value: String,
        remainingPercent: Double?,
        isLunaReserve: Bool = false,
        resetEmphasis: CGFloat = 0,
        isResetScheduled: Bool = false,
        bellRotation: Double = 0
    ) {
        self.value = value
        self.remainingPercent = remainingPercent
        self.isLunaReserve = isLunaReserve
        self.resetEmphasis = resetEmphasis
        self.isResetScheduled = isResetScheduled
        self.bellRotation = bellRotation
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

            if self.isResetScheduled {
                TraeBell()
                    .stroke(TraeTheme.Palette.statusWarning, lineWidth: 1)
                    .frame(width: 11, height: 11)
                    .rotationEffect(.degrees(self.bellRotation), anchor: .top)
                    .frame(width: 18, height: 16)
            }

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
