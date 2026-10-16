import SwiftUI

struct DayEnergySheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let onAnswer: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How was your energy today?")
                .font(theme.display(.title3))
                .foregroundStyle(theme.colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { level in
                    Button {
                        onAnswer(level)
                        dismiss()
                    } label: {
                        Text("\(level)")
                            .font(theme.number(.title3))
                            .foregroundStyle(theme.colors.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.pressScale)
                    .accessibilityLabel("Energy today, \(level) of 5")
                }
            }
            Text("1 very low · 5 very high")
                .font(theme.body(.caption))
                .foregroundStyle(theme.colors.textSecondary)
            Button("Skip") { dismiss() }
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.colors.background.ignoresSafeArea())
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}
