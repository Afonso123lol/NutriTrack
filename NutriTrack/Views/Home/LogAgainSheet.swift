import SwiftUI
import CoreData

struct LogAgainSheet: View {
    @ObservedObject var entry: FoodEntry

    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var multiplier = 1.0
    @State private var custom = ""

    private var effective: Double? {
        custom.trimmingCharacters(in: .whitespaces).isEmpty ? multiplier : MealEditor.multiplier(from: custom)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(entry.dishName ?? "Meal")
                    .font(theme.display(.title3))
                    .foregroundStyle(theme.colors.textPrimary)

                Picker("Portion", selection: $multiplier) {
                    ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { value in
                        Text(String(format: "%g×", value)).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Other portion, e.g. 0.8", text: $custom)
                    .keyboardType(.decimalPad)
                    .padding(12)
                    .background(theme.colors.surface,
                                in: RoundedRectangle(cornerRadius: theme.shape.controlRadius, style: .continuous))
                    .foregroundStyle(theme.colors.textPrimary)

                if let effective {
                    Text(String(format: "%.0f kcal · %.0fg protein · %.0fg carbs · %.0fg fat",
                                entry.calories * effective, entry.proteinG * effective,
                                entry.carbsG * effective, entry.fatG * effective))
                        .font(theme.number(.subheadline))
                        .foregroundStyle(theme.colors.textSecondary)
                } else {
                    Text("Enter a portion between 0.1 and 10.")
                        .font(theme.body(.subheadline))
                        .foregroundStyle(theme.colors.warning)
                }

                Button("Log now") {
                    if let effective {
                        FoodEntry.logAgain(entry, multiplier: effective, in: ctx)
                        dismiss()
                    }
                }
                .buttonStyle(.themedPrimary)
                .disabled(effective == nil)

                Spacer()
            }
            .padding(16)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Log again")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
