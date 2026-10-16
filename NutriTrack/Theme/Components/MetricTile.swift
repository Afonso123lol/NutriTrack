import SwiftUI

struct MetricTile: View {
    @Environment(\.theme) private var theme
    let label: String
    let value: String
    var unit: String? = nil
    var bar: TargetBarGeometry? = nil
    var color: Color? = nil
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowText(label)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(theme.number(22))
                    .foregroundStyle(theme.colors.textPrimary)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(theme.meta(.caption))
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            if let bar {
                TargetBar(geometry: bar, color: color ?? theme.colors.accent)
            }
            if let caption {
                Text(caption)
                    .font(theme.meta(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .themedCard(padding: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue([value, unit, caption].compactMap { $0 }.joined(separator: " "))
    }
}
