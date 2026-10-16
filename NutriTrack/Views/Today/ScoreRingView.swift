import SwiftUI

struct ScoreRingView: View {
    @Environment(\.theme) private var theme
    let label: String
    let score: Int?
    let color: Color
    let icon: String
    var size: CGFloat = 92
    var placeholder: String? = nil

    var body: some View {
        let inset = theme.shape.ringWidth / 2
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .inset(by: inset)
                    .stroke(color.opacity(0.15), lineWidth: theme.shape.ringWidth)
                Circle()
                    .inset(by: inset)
                    .trim(from: 0, to: CGFloat(score ?? 0) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: theme.shape.ringWidth, lineCap: theme.shape.ringCap))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: score)
                if let score {
                    Text("\(score)")
                        .font(theme.number(size * 0.28))
                        .foregroundStyle(theme.colors.textPrimary)
                } else if let placeholder {
                    Text(placeholder)
                        .font(theme.number(size * 0.28))
                        .foregroundStyle(theme.colors.textMuted)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.22))
                        .foregroundStyle(theme.colors.textMuted)
                }
            }
            .frame(width: size, height: size)
            Text(label)
                .font(theme.body(.caption).weight(.semibold))
                .foregroundStyle(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(score.map { "\($0) out of 100" } ?? "Not available yet")
    }
}
