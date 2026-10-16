import SwiftUI

struct NutrientRangeRow: View {
    @Environment(\.theme) private var theme
    let reading: NutrientReading

    private var color: Color {
        guard reading.showsStatus, reading.rule != .plain else { return theme.colors.textSecondary }
        switch reading.status {
        case .low: return theme.colors.textSecondary
        case .good: return theme.colors.success
        case .over: return theme.colors.danger
        }
    }

    private var spokenLabel: String {
        [reading.name, reading.amount, reading.word].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                Text(reading.name)
                    .font(theme.body(.subheadline))
                    .foregroundStyle(theme.colors.textPrimary)
                    .accessibilityLabel(spokenLabel)
                NutrientInfoButton(label: reading.name, basis: reading.basis)
                Spacer(minLength: 8)
                if !reading.word.isEmpty {
                    Text(reading.word)
                        .font(theme.meta(.caption).weight(.semibold))
                        .foregroundStyle(color)
                        .accessibilityHidden(true)
                }
            }
            if reading.rule != .plain {
                TargetBar(geometry: reading.geometry, color: color,
                          zoneColor: reading.showsStatus ? theme.colors.success : nil)
            }
            Text(reading.amount)
                .font(theme.meta(.caption))
                .foregroundStyle(theme.colors.textSecondary)
                .accessibilityHidden(true)
            if let note = reading.supplementNote ?? reading.note {
                Text(note)
                    .font(theme.body(.caption2))
                    .foregroundStyle(theme.colors.textMuted)
            }
        }
    }
}
