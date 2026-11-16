import SwiftUI

struct SuggestionCard: View {
    @Environment(\.theme) private var theme
    let text: String
    let onApply: () -> Void
    let onKeep: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowText("Suggestion")
            Text(text)
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("App rule. You decide.")
                .font(theme.body(.caption))
                .foregroundStyle(theme.colors.textSecondary)
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
        Button("Use the lighter session", action: onApply)
            .buttonStyle(.themedOutline)
            .lineLimit(1)
        Button("Keep the plan", action: onKeep)
            .buttonStyle(.themedOutline)
            .lineLimit(1)
    }
}
