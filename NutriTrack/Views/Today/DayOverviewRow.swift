import SwiftUI

struct DayOverviewRow: View {
    @Environment(\.theme) private var theme
    let overview: DayOverview
    let tone: Color
    var weekPath: WeekPath? = nil
    let onSleep: () -> Void
    let onFood: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if theme.style.hero == .path, let weekPath, weekPath.totalPlanned > 0 {
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
            HStack(alignment: .top, spacing: 8) {
                card(overview.today, valueColor: tone)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(overview.today.accessibility)
                Button(action: onSleep) { card(overview.sleep, valueColor: theme.colors.textPrimary) }
                    .buttonStyle(.pressScale)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(overview.sleep.accessibility)
                    .accessibilityHint("Opens your sleep")
                    .accessibilityAddTraits(.isButton)
                Button(action: onFood) { card(overview.food, valueColor: theme.colors.textPrimary) }
                    .buttonStyle(.pressScale)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(overview.food.accessibility)
                    .accessibilityHint("Opens Nutrition")
                    .accessibilityAddTraits(.isButton)
            }
        }
    }

    private func card(_ card: DayOverview.Card, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.title)
                .font(theme.body(.caption))
                .foregroundStyle(theme.colors.textSecondary)
            Text(card.value)
                .font(theme.number(22))
                .foregroundStyle(valueColor)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            Text(card.detail)
                .font(theme.body(.caption2))
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(2)
            if let extra = card.extra {
                Text(extra)
                    .font(theme.body(.caption2))
                    .foregroundStyle(theme.colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
