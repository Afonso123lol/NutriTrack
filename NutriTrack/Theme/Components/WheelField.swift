import SwiftUI

struct NumberWheelField: View {
    @Environment(\.theme) private var theme
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Int>
    var hasTenths = false
    let unit: String

    @State private var isPicking = false

    private var text: String {
        hasTenths ? String(format: "%.1f %@", value, unit) : String(format: "%.0f %@", value, unit)
    }

    var body: some View {
        Button { isPicking = true } label: {
            HStack(spacing: 8) {
                Text(title)
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
                Text(text)
                    .font(theme.number(.body))
                    .foregroundStyle(theme.colors.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(theme.colors.textMuted)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(text)
        .sheet(isPresented: $isPicking) {
            NumberWheelSheet(title: title, value: value, range: range, hasTenths: hasTenths, unit: unit,
                             confirmTitle: "Done") { value = $0 }
        }
    }
}

struct NumberWheelSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let title: String
    let range: ClosedRange<Int>
    let hasTenths: Bool
    let unit: String
    let confirmTitle: String
    let onConfirm: (Double) -> Void

    @State private var whole: Int
    @State private var tenth: Int

    init(title: String, value: Double, range: ClosedRange<Int>, hasTenths: Bool, unit: String,
         confirmTitle: String, onConfirm: @escaping (Double) -> Void) {
        self.title = title
        self.range = range
        self.hasTenths = hasTenths
        self.unit = unit
        self.confirmTitle = confirmTitle
        self.onConfirm = onConfirm
        let split = WheelValue.split(hasTenths ? value : value.rounded(), in: range)
        _whole = State(initialValue: split.whole)
        _tenth = State(initialValue: split.tenth)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 4) {
                Picker(title, selection: $whole) {
                    ForEach(Array(range), id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(width: 110)
                if hasTenths {
                    Text(".")
                        .font(theme.number(.title2))
                        .foregroundStyle(theme.colors.textPrimary)
                    Picker("Tenths", selection: $tenth) {
                        ForEach(0..<10, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                }
                Text(unit)
                    .font(theme.body(.title3))
                    .foregroundStyle(theme.colors.textSecondary)
                    .padding(.leading, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle) {
                        onConfirm(WheelValue.combine(whole: whole, tenth: tenth, in: range))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

struct DateWheelField: View {
    @Environment(\.theme) private var theme
    let title: String
    let date: Date?
    let range: ClosedRange<Date>
    let suggested: Date
    let onPick: (Date) -> Void

    @State private var isPicking = false

    private var text: String { date?.formatted(date: .abbreviated, time: .omitted) ?? "Add" }

    var body: some View {
        Button { isPicking = true } label: {
            HStack(spacing: 8) {
                Text(title)
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
                Text(text)
                    .font(theme.number(.body))
                    .foregroundStyle(date == nil ? theme.colors.accent : theme.colors.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(theme.colors.textMuted)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(text)
        .sheet(isPresented: $isPicking) {
            DateWheelSheet(title: title, date: date ?? suggested, range: range, components: .date,
                           confirmTitle: "Done", onConfirm: onPick)
        }
    }
}

struct DateWheelSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let title: String
    let range: ClosedRange<Date>
    let components: DatePickerComponents
    let confirmTitle: String
    let onConfirm: (Date) -> Void

    @State private var date: Date

    init(title: String, date: Date, range: ClosedRange<Date>, components: DatePickerComponents,
         confirmTitle: String, onConfirm: @escaping (Date) -> Void) {
        self.title = title
        self.range = range
        self.components = components
        self.confirmTitle = confirmTitle
        self.onConfirm = onConfirm
        _date = State(initialValue: min(max(date, range.lowerBound), range.upperBound))
    }

    var body: some View {
        NavigationStack {
            DatePicker(title, selection: $date, in: range, displayedComponents: components)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.colors.background.ignoresSafeArea())
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(confirmTitle) {
                            onConfirm(date)
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.height(300)])
    }
}
