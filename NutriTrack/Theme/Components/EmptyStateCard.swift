import SwiftUI

struct EmptyStateCard: View {
    @Environment(\.theme) private var theme
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(theme.colors.textMuted)
            Text(title)
                .font(theme.display(.title3))
                .foregroundStyle(theme.colors.textPrimary)
            Text(message)
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textSecondary)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.themedPrimary)
                    .padding(.top, 4)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .themedCard()
    }
}
