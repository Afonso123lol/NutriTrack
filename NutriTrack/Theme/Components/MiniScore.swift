import SwiftUI

struct MiniScore: View {
    @Environment(\.theme) private var theme
    let label: String
    let score: Int?
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(theme.colors.border, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(score ?? 0) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text(score.map(String.init) ?? "—")
                    .font(theme.number(20))
                    .foregroundStyle(score == nil ? theme.colors.textMuted : theme.colors.textPrimary)
                    .contentTransition(.numericText())
                Text(label)
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(score.map { "\($0) out of 100" } ?? "Not available yet")
    }
}
