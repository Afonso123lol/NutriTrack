import SwiftUI

struct HeroScore: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let readiness: Int?
    let sleep: Int?
    let diet: Int?
    var baselineDelta: Int? = nil
    var weekPath: WeekPath? = nil
    let tone: Color
    var onSelect: (ScoreKind) -> Void = { _ in }

    @State private var progress = 0.0

    private func fraction(_ score: Int?) -> Double {
        Double(min(max(score ?? 0, 0), 100)) / 100
    }

    var body: some View {
        Group {
            switch theme.style.hero {
            case .arc: arc
            case .numeral: numeral
            case .path: pathHero
            }
        }
        .onAppear {
            if reduceMotion {
                progress = 1
            } else {
                withAnimation(.easeOut(duration: 0.9)) { progress = 1 }
            }
        }
    }

    @ViewBuilder
    private func scoreText(_ score: Int?, size: CGFloat) -> some View {
        if let score {
            Text("\(score)")
                .font(theme.hero(size))
                .foregroundStyle(theme.colors.textPrimary)
                .contentTransition(.numericText())
        } else {
            Text("after\ncheck-in")
                .font(theme.body(.caption))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.colors.textMuted)
        }
    }

    private func scoreButton<Label: View>(_ kind: ScoreKind, score: Int?,
                                          @ViewBuilder label: () -> Label) -> some View {
        Button { onSelect(kind) } label: { label() }
            .buttonStyle(.pressScale)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(kind.rawValue)
            .accessibilityValue(score.map { "\($0) out of 100" } ?? "Not available yet")
            .accessibilityAddTraits(.isButton)
    }

    private var arc: some View {
        HStack(spacing: 20) {
            scoreButton(.readiness, score: readiness) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(theme.colors.border,
                                style: StrokeStyle(lineWidth: theme.shape.ringWidth, lineCap: .round))
                        .rotationEffect(.degrees(135))
                    Circle()
                        .trim(from: 0, to: 0.75 * fraction(readiness) * progress)
                        .stroke(tone, style: StrokeStyle(lineWidth: theme.shape.ringWidth, lineCap: .round))
                        .rotationEffect(.degrees(135))
                    VStack(spacing: 2) {
                        scoreText(readiness, size: 56)
                        EyebrowText("Readiness")
                    }
                }
                .frame(width: 156, height: 156)
                .padding(.bottom, -16)
            }
            VStack(alignment: .leading, spacing: 10) {
                scoreButton(.sleep, score: sleep) {
                    MiniScore(label: "Sleep", score: sleep, color: theme.colors.sleep)
                }
                scoreButton(.diet, score: diet) {
                    MiniScore(label: "Diet", score: diet, color: theme.colors.diet)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var numeral: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                scoreButton(.readiness, score: readiness) {
                    VStack(alignment: .leading, spacing: 0) {
                        EyebrowText("Readiness")
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            scoreText(readiness, size: 88)
                            if readiness != nil {
                                Text("%")
                                    .font(theme.number(22))
                                    .foregroundStyle(theme.colors.textSecondary)
                            }
                        }
                    }
                }
                Spacer()
                if let baselineDelta {
                    Text("\(baselineDelta >= 0 ? "▲" : "▼") \(abs(baselineDelta)) vs 28 d")
                        .font(theme.meta(.caption))
                        .foregroundStyle(tone)
                }
            }
            TargetBar(geometry: TargetBarGeometry(fill: fraction(readiness), tick: nil, zone: nil, isOver: false),
                      color: theme.colors.accent, isProminent: true)
            HStack(spacing: 8) {
                scoreButton(.sleep, score: sleep) { cell("Sleep", sleep.map(String.init) ?? "—", unit: nil) }
                scoreButton(.diet, score: diet) { cell("Diet", diet.map(String.init) ?? "—", unit: nil) }
                if let weekPath, weekPath.totalPlanned > 0 {
                    cell("Week", "\(Int(weekPath.doneSoFar))", unit: "/\(Int(weekPath.totalPlanned))")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("This week")
                        .accessibilityValue("\(Int(weekPath.doneSoFar)) of \(Int(weekPath.totalPlanned)) minutes")
                }
            }
        }
    }

    private func cell(_ label: String, _ value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            EyebrowText(label)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(theme.number(28))
                    .foregroundStyle(theme.colors.textPrimary)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(theme.meta(.caption2))
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .themedCard(padding: 10)
    }

    private var pathHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let weekPath, weekPath.totalPlanned > 0 {
                WeekPathChart(path: weekPath, color: theme.colors.readiness)
                HStack {
                    Text(weekPath.status.label)
                        .font(theme.body(.caption).weight(.semibold))
                        .foregroundStyle(theme.colors.readiness)
                    Spacer()
                    Text("\(Int(weekPath.doneSoFar)) of \(Int(weekPath.totalPlanned)) min this week")
                        .font(theme.body(.caption))
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
            HStack(spacing: 8) {
                scoreButton(.readiness, score: readiness) { pill("Readiness", readiness, isMain: true) }
                scoreButton(.sleep, score: sleep) { pill("Sleep", sleep, isMain: false) }
                scoreButton(.diet, score: diet) { pill("Diet", diet, isMain: false) }
            }
        }
    }

    private func pill(_ label: String, _ score: Int?, isMain: Bool) -> some View {
        let isLarge = weekPath == nil || weekPath?.totalPlanned == 0
        return VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(theme.body(.caption))
                .foregroundStyle(isMain ? theme.colors.onAccent.opacity(0.85) : theme.colors.textSecondary)
            Text(score.map(String.init) ?? "—")
                .font(theme.number(isLarge ? 32 : 24))
                .foregroundStyle(isMain ? theme.colors.onAccent : theme.colors.textPrimary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, isLarge ? 14 : 10)
        .background(isMain ? theme.colors.accent : theme.colors.surface,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
