import SwiftUI

struct StatCard: View {
    @Environment(\.theme) private var theme
    let label: String
    let value: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            EyebrowText(label)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(theme.number(.title3))
                    .foregroundStyle(theme.colors.textPrimary)
                if let detail {
                    Text(detail)
                        .font(theme.body(.caption))
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .themedCard(padding: 12)
    }
}
