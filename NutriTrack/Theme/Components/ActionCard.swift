import SwiftUI

struct ActionCard: View {
    @Environment(\.theme) private var theme
    let eyebrow: String
    let title: String
    var detail: String? = nil
    var note: String? = nil
    var buttonTitle: String? = nil
    var action: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowText(eyebrow)
            Text(title)
                .font(theme.body(.headline))
                .foregroundStyle(theme.colors.textPrimary)
            if let detail {
                Text(detail)
                    .font(theme.body(.subheadline))
                    .foregroundStyle(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let note {
                Text(note)
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.dayEasy)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let buttonTitle {
                Button(buttonTitle, action: action)
                    .buttonStyle(.themedCompact)
                    .padding(.top, 6)
            }
        }
        .themedCard()
    }
}
