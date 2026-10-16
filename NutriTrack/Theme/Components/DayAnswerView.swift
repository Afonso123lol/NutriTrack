import SwiftUI

struct DayAnswerView: View {
    @Environment(\.theme) private var theme
    let headline: DayHeadline
    let date: Date
    let tone: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(headline.eyebrow) · \(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
                .font(theme.meta(.caption).weight(.semibold))
                .tracking(theme.typography.eyebrowTracking)
                .textCase(theme.typography.isEyebrowUppercase ? .uppercase : nil)
                .foregroundStyle(tone)
            Text(headline.title)
                .font(theme.display(.largeTitle))
                .tracking(theme.typography.titleTracking)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            Text(headline.reason)
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
