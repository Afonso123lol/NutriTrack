import SwiftUI

struct DayStateBoardView: View {
    @Environment(\.theme) private var theme
    let board: DayStateBoard
    let onSleep: () -> Void
    let onScale: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowText("Today's state")
            if let sleep = board.sleep {
                Button(action: onSleep) { sleepRow(sleep) }
                    .buttonStyle(.plain)
            }
            ForEach(Array(board.rows.enumerated()), id: \.offset) { index, row in
                Button { onScale(index) } label: { scaleRow(row) }
                    .buttonStyle(.plain)
            }
            if board.isIll { flag("Marked ill today") }
            if board.hasPain { flag("Marked pain that changes how you walk") }
            Text(board.footer)
                .font(theme.body(.caption))
                .foregroundStyle(theme.colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func sleepRow(_ sleep: DayStateBoard.SleepRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(sleep.valueText)
                    .font(theme.body(.subheadline).weight(.semibold))
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
                Text(sleep.needText)
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
                chevron
            }
            TargetBar(geometry: TargetBarGeometry(fill: sleep.fraction, tick: nil, zone: nil, isOver: false),
                      color: theme.colors.sleep, isProminent: false)
            if sleep.isShort {
                Text("Short night")
                    .font(theme.body(.caption).weight(.semibold))
                    .foregroundStyle(theme.colors.warning)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your sleep")
    }

    private func scaleRow(_ row: DayStateBoard.ScaleRow) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.valueText)
                    .font(theme.body(.subheadline).weight(.semibold))
                    .foregroundStyle(theme.colors.textPrimary)
                if let band = row.bandText {
                    Text(band)
                        .font(theme.body(.caption))
                        .foregroundStyle(row.isUnfavourable ? theme.colors.warning : theme.colors.textSecondary)
                }
            }
            Spacer()
            if let usual = row.usualText {
                Text(usual)
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            chevron
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the last \(DayStateBoard.windowDays) days")
    }

    private func flag(_ text: String) -> some View {
        Text(text)
            .font(theme.body(.subheadline).weight(.semibold))
            .foregroundStyle(theme.colors.danger)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(theme.colors.textMuted)
            .accessibilityHidden(true)
    }
}
