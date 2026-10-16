import SwiftUI

struct SupplementRowView: View {
    @Environment(\.theme) private var theme
    let template: SupplementTemplate
    let onLog: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name ?? "Supplement")
                    .font(theme.body(.subheadline).weight(.medium))
                    .foregroundStyle(theme.colors.textPrimary)
                if let brand = template.brand, !brand.isEmpty {
                    Text(brand)
                        .font(theme.body(.caption))
                        .foregroundStyle(theme.colors.textSecondary)
                }
                Text(template.dosageDescription ?? "1 dose")
                    .font(theme.body(.caption2))
                    .foregroundStyle(theme.colors.textMuted)
            }
            Spacer()
            Button {
                onLog()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.colors.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log \(template.name ?? "supplement")")
        }
        .padding(.vertical, 4)
    }
}
