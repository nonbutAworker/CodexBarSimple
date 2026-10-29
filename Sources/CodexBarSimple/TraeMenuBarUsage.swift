import SwiftUI

struct TraeMenuBarUsage: View {
    let value: String
    let remainingPercent: Double?
    let isLunaReserve: Bool
    let resetEmphasis: CGFloat
    let isResetScheduled: Bool
    let bellRotation: Double
    var systemColorScheme: ColorScheme?
    @Environment(\.colorScheme) private var inheritedColorScheme

    init(
        value: String,
        remainingPercent: Double?,
        isLunaReserve: Bool = false,
        resetEmphasis: CGFloat = 0,
        isResetScheduled: Bool = false,
        bellRotation: Double = 0,
        systemColorScheme: ColorScheme? = nil
    ) {
        self.value = value
        self.remainingPercent = remainingPercent
        self.isLunaReserve = isLunaReserve
        self.resetEmphasis = resetEmphasis
        self.isResetScheduled = isResetScheduled
        self.bellRotation = bellRotation
        self.systemColorScheme = systemColorScheme
    }

    var body: some View {
        Group {
            if #available(macOS 26, *) {
                self.content
                    .glassEffect(.regular, in: .rect(cornerRadius: TraeTheme.Radius.medium))
            } else {
                self.content
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: TraeTheme.Radius.medium))
            }
        }
        .overlay {
            if self.isResetScheduled {
                RoundedRectangle(cornerRadius: TraeTheme.Radius.medium)
                    .strokeBorder(TraeTheme.Palette.statusWarning, lineWidth: 1.5)
            }
        }
        .environment(\.colorScheme, self.systemColorScheme ?? self.inheritedColorScheme)
    }

    private var content: some View {
        HStack(spacing: 1.5) {
            if self.isLunaReserve {
                Image(systemName: "moon.fill")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(self.metricColor)
                    .frame(width: 8)
            }

            self.metricLabel

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
                        .fill(.primary.opacity(0.12))

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
    }

    var metricLabel: some View {
        Text(self.value)
            .font(TraeTheme.Typography.menuMetric(size: self.metricFontSize))
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: self.metricColor, location: 0),
                        .init(color: self.metricColor.opacity(0.94), location: 0.36),
                        .init(color: self.metricColor.opacity(0.56), location: 0.52),
                        .init(color: self.metricColor.opacity(0.92), location: 0.66),
                        .init(color: self.metricColor.opacity(0.82), location: 1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing)
            )
            .shadow(color: .white.opacity(0.20), radius: 0, x: 0, y: -0.3)
            .shadow(color: .black.opacity(0.20), radius: 0.4, x: 0, y: 0.4)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
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
        return .primary
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

#if DEBUG
    #Preview("Liquid Glass states") {
        VStack(spacing: 12) {
            TraeMenuBarUsage(value: "33%", remainingPercent: 33)
            TraeMenuBarUsage(value: "6%", remainingPercent: 6)
            TraeMenuBarUsage(value: "95%", remainingPercent: 95, isLunaReserve: true)
            TraeMenuBarUsage(value: "33%", remainingPercent: 33, isResetScheduled: true)
            TraeMenuBarUsage(value: "100%", remainingPercent: 100, resetEmphasis: 1)
            TraeMenuBarUsage(value: "--%", remainingPercent: nil)
        }
        .padding(24)
        .background(
            LinearGradient(colors: [.blue.opacity(0.2), .mint.opacity(0.3)], startPoint: .top, endPoint: .bottom))
    }
#endif
