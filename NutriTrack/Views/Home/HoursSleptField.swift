import SwiftUI

struct HoursSleptField: View {
    @Environment(\.theme) private var theme
    @Binding var hours: Double
    @State private var isPicking = false

    var body: some View {
        Button { isPicking = true } label: {
            HStack(spacing: 8) {
                Text("Hours slept")
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
                Text(TimeInBed.label(hours))
                    .font(theme.number(.body))
                    .foregroundStyle(theme.colors.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(theme.colors.textMuted)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hours slept")
        .accessibilityValue(TimeInBed.label(hours))
        .sheet(isPresented: $isPicking) {
            HoursSleptSheet(hours: hours) { hours = $0 }
        }
    }
}

struct HoursSleptSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let onConfirm: (Double) -> Void

    @State private var whole: Int
    @State private var minutes: Int

    init(hours: Double, onConfirm: @escaping (Double) -> Void) {
        self.onConfirm = onConfirm
        let split = TimeInBed.split(hours)
        _whole = State(initialValue: split.hours)
        _minutes = State(initialValue: split.minutes)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 4) {
                Picker("Hours", selection: $whole) {
                    ForEach(Int(TimeInBed.range.lowerBound)...Int(TimeInBed.range.upperBound), id: \.self) {
                        Text("\($0)").tag($0)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 90)
                Text("h")
                    .font(theme.body(.title3))
                    .foregroundStyle(theme.colors.textSecondary)
                Picker("Minutes", selection: $minutes) {
                    ForEach(TimeInBed.minuteOptions, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(width: 90)
                Text("min")
                    .font(theme.body(.title3))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Hours slept")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onConfirm(TimeInBed.combine(hours: whole, minutes: minutes))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}
