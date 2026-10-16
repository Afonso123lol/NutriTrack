import SwiftUI

struct LightWeekCard: View {
    @Environment(\.theme) private var theme
    let onApply: () -> Void
    let onKeep: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowText("This week")
            Text("Three low days this week. Make the rest of the week lighter?")
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { buttons }
                VStack(alignment: .leading, spacing: 10) { buttons }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    @ViewBuilder
    private var buttons: some View {
        Button("Make it lighter", action: onApply)
            .buttonStyle(.themedOutline)
            .lineLimit(1)
        Button("Keep the plan", action: onKeep)
            .buttonStyle(.themedOutline)
            .lineLimit(1)
    }
}
