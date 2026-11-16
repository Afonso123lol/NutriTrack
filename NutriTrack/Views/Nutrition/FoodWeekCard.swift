import SwiftUI

struct FoodWeekCard: View {
    @Environment(\.theme) private var theme
    let week: FoodWeek

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                EyebrowText("Food week")
                Spacer()
                Text(week.completeText)
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            if week.caloriesText == nil {
                Text("Close a day as complete to see your week here.")
                    .font(theme.body(.subheadline))
                    .foregroundStyle(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            row("Calories", week.caloriesText, detail: week.caloriesRangeText)
            row("Protein", week.proteinText)
            row("Fibre", week.fiberText)
            row("Saturated fat", week.saturatedText)
            row("Sodium", week.sodiumText, detail: week.sodiumNote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    @ViewBuilder
    private func row(_ title: String, _ value: String?, detail: String? = nil) -> some View {
        if let value {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.body(.caption).weight(.semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                Text(value)
                    .font(theme.body(.subheadline))
                    .foregroundStyle(theme.colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(theme.body(.caption))
                        .foregroundStyle(theme.colors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
