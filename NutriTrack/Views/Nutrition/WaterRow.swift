import SwiftUI

struct WaterRow: View {
    @Environment(\.theme) private var theme
    @AppStorage("waterMlToday") private var waterMlToday: Double = 0
    @AppStorage("waterResetDate") private var waterResetDate: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .foregroundStyle(theme.colors.water)
                .font(.subheadline)
            Text(String(format: "%.0f ml", waterMlToday))
                .font(theme.number(.subheadline))
                .foregroundStyle(theme.colors.textPrimary)
                .contentTransition(.numericText())
            Text("water")
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textSecondary)
            Spacer()
            Button {
                waterMlToday = max(0, waterMlToday - 250)
            } label: {
                Image(systemName: "minus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(theme.colors.surfaceElevated, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove 250 millilitres")
            Button {
                waterMlToday += 250
            } label: {
                Text("+250 ml")
                    .font(theme.body(.caption).weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(theme.colors.water.opacity(0.15), in: Capsule())
                    .foregroundStyle(theme.colors.water)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add 250 millilitres")
        }
        .onAppear {
            let todayStart = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
            if waterResetDate < todayStart {
                waterMlToday = 0
                waterResetDate = todayStart
            }
        }
    }
}
