import SwiftUI

struct MealEditSheet: View {
    let onSave: (NutritionAnalysis) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var base: NutritionAnalysis
    @State private var name: String
    @State private var calories: Double
    @State private var proteinG: Double
    @State private var carbsG: Double
    @State private var fatG: Double
    @State private var alcoholG: Double
    @State private var customMultiplier = ""

    init(analysis: NutritionAnalysis, onSave: @escaping (NutritionAnalysis) -> Void) {
        self.onSave = onSave
        _base = State(initialValue: analysis)
        _name = State(initialValue: analysis.dishName)
        _calories = State(initialValue: analysis.calories)
        _proteinG = State(initialValue: analysis.proteinG)
        _carbsG = State(initialValue: analysis.carbsG)
        _fatG = State(initialValue: analysis.fatG)
        _alcoholG = State(initialValue: analysis.alcoholG ?? 0)
    }

    private var current: NutritionAnalysis {
        MealEditor.edited(base, dishName: name, calories: calories, proteinG: proteinG,
                          carbsG: carbsG, fatG: fatG, alcoholG: alcoholG)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Name", text: $name)
                }
                .listRowBackground(theme.colors.surface)

                Section {
                    numberField("Calories (kcal)", value: $calories)
                    numberField("Protein (g)", value: $proteinG)
                    numberField("Carbohydrates (g)", value: $carbsG)
                    numberField("Fat (g)", value: $fatG)
                    numberField("Alcohol (g)", value: $alcoholG)
                } header: {
                    Text("Values")
                } footer: {
                    Text("Change a macro and the calories are recalculated. Type the calories yourself and that number is kept.")
                }
                .listRowBackground(theme.colors.surface)

                Section {
                    HStack(spacing: 10) {
                        ForEach([0.5, 1.5, 2.0], id: \.self) { multiplier in
                            Button(String(format: "%g×", multiplier)) { scale(by: multiplier) }
                        }
                    }
                    .buttonStyle(.bordered)
                    HStack {
                        TextField("Custom, e.g. 0.8", text: $customMultiplier)
                            .keyboardType(.decimalPad)
                        Button("Apply") {
                            if let multiplier = MealEditor.multiplier(from: customMultiplier) {
                                scale(by: multiplier)
                                customMultiplier = ""
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(MealEditor.multiplier(from: customMultiplier) == nil)
                    }
                } header: {
                    Text("Adjust portion")
                } footer: {
                    Text("Scales every nutrient, micronutrients included. Between 0.1× and 10×.")
                }
                .listRowBackground(theme.colors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(current)
                        dismiss()
                    }
                }
            }
        }
    }

    private func numberField(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
            TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
        }
    }

    private func scale(by multiplier: Double) {
        let scaled = MealEditor.scaled(current, by: multiplier)
        base = scaled
        name = scaled.dishName
        calories = scaled.calories
        proteinG = scaled.proteinG
        carbsG = scaled.carbsG
        fatG = scaled.fatG
        alcoholG = scaled.alcoholG ?? 0
    }
}
