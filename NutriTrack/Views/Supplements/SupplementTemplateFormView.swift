import SwiftUI
import CoreData

struct SupplementTemplateFormView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    let template: SupplementTemplate?

    @State private var name = ""
    @State private var brand = ""
    @State private var dosageDescription = "1 capsule/day"
    @State private var bioactivesJson = ""
    @State private var vitaminAUg = 0.0
    @State private var vitaminCMg = 0.0
    @State private var vitaminDUg = 0.0
    @State private var vitaminEMg = 0.0
    @State private var vitaminKUg = 0.0
    @State private var vitaminB1Mg = 0.0
    @State private var vitaminB2Mg = 0.0
    @State private var vitaminB3Mg = 0.0
    @State private var vitaminB5Mg = 0.0
    @State private var vitaminB6Mg = 0.0
    @State private var vitaminB12Ug = 0.0
    @State private var folateUg = 0.0
    @State private var ironMg = 0.0
    @State private var zincMg = 0.0
    @State private var magnesiumMg = 0.0
    @State private var calciumMg = 0.0
    @State private var seleniumUg = 0.0
    @State private var copperUg = 0.0
    @State private var omega3G = 0.0
    @State private var calories = 0.0
    @State private var proteinG = 0.0
    @State private var carbsG = 0.0
    @State private var fatG = 0.0
    @State private var fiberG = 0.0
    @State private var sugarG = 0.0
    @State private var sodiumMg = 0.0
    @State private var potassiumMg = 0.0
    @State private var phosphorusMg = 0.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name (e.g. Win-Fit MC)", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    TextField("Dosage", text: $dosageDescription)
                }
                .listRowBackground(theme.colors.surface)
                Section("Energy and macros per dose") {
                    nutrientField("Calories (kcal)", value: $calories)
                    nutrientField("Protein (g)", value: $proteinG)
                    nutrientField("Carbohydrates (g)", value: $carbsG)
                    nutrientField("Sugar (g)", value: $sugarG)
                    nutrientField("Fiber (g)", value: $fiberG)
                    nutrientField("Fat (g)", value: $fatG)
                }
                .listRowBackground(theme.colors.surface)
                Section("Vitamins per dose") {
                    nutrientField("Vitamin A (µg)", value: $vitaminAUg)
                    nutrientField("Vitamin C (mg)", value: $vitaminCMg)
                    nutrientField("Vitamin D (µg)", value: $vitaminDUg)
                    nutrientField("Vitamin E (mg)", value: $vitaminEMg)
                    nutrientField("Vitamin K (µg)", value: $vitaminKUg)
                    nutrientField("B1 Thiamine (mg)", value: $vitaminB1Mg)
                    nutrientField("B2 Riboflavin (mg)", value: $vitaminB2Mg)
                    nutrientField("B3 Niacin (mg)", value: $vitaminB3Mg)
                    nutrientField("B5 Pantothenic (mg)", value: $vitaminB5Mg)
                    nutrientField("B6 (mg)", value: $vitaminB6Mg)
                    nutrientField("B12 (µg)", value: $vitaminB12Ug)
                    nutrientField("Folate (µg)", value: $folateUg)
                }
                .listRowBackground(theme.colors.surface)
                Section("Minerals per dose") {
                    nutrientField("Sodium (mg)", value: $sodiumMg)
                    nutrientField("Potassium (mg)", value: $potassiumMg)
                    nutrientField("Phosphorus (mg)", value: $phosphorusMg)
                    nutrientField("Iron (mg)", value: $ironMg)
                    nutrientField("Zinc (mg)", value: $zincMg)
                    nutrientField("Magnesium (mg)", value: $magnesiumMg)
                    nutrientField("Calcium (mg)", value: $calciumMg)
                    nutrientField("Selenium (µg)", value: $seleniumUg)
                    nutrientField("Copper (µg)", value: $copperUg)
                }
                .listRowBackground(theme.colors.surface)
                Section("Other") {
                    nutrientField("Omega-3 (g)", value: $omega3G)
                    TextField("Other compounds (JSON)", text: $bioactivesJson, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                        .font(theme.body(.caption))
                }
                .listRowBackground(theme.colors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(template == nil ? "New Supplement" : "Edit Supplement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.isEmpty)
                }
            }
            .onAppear { loadTemplate() }
        }
    }

    private func nutrientField(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func loadTemplate() {
        guard let t = template else { return }
        name = t.name ?? ""; brand = t.brand ?? ""
        dosageDescription = t.dosageDescription ?? "1 capsule/day"
        bioactivesJson = t.bioactivesJson ?? ""
        vitaminAUg = t.vitaminAUg
        vitaminCMg = t.vitaminCMg; vitaminDUg = t.vitaminDUg; vitaminEMg = t.vitaminEMg
        vitaminKUg = t.vitaminKUg; vitaminB1Mg = t.vitaminB1Mg; vitaminB2Mg = t.vitaminB2Mg
        vitaminB3Mg = t.vitaminB3Mg; vitaminB5Mg = t.vitaminB5Mg; vitaminB6Mg = t.vitaminB6Mg
        vitaminB12Ug = t.vitaminB12Ug; folateUg = t.folateUg; ironMg = t.ironMg
        zincMg = t.zincMg; magnesiumMg = t.magnesiumMg; calciumMg = t.calciumMg
        seleniumUg = t.seleniumUg; copperUg = t.copperUg; omega3G = t.omega3G
        calories = t.calories; proteinG = t.proteinG; carbsG = t.carbsG; fatG = t.fatG
        fiberG = t.fiberG; sugarG = t.sugarG; sodiumMg = t.sodiumMg
        potassiumMg = t.potassiumMg; phosphorusMg = t.phosphorusMg
    }

    private func save() {
        let t = template ?? SupplementTemplate(context: ctx)
        if template == nil { t.id = UUID() }
        t.name = name; t.brand = brand; t.dosageDescription = dosageDescription
        t.bioactivesJson = bioactivesJson
        t.vitaminAUg = vitaminAUg
        t.vitaminCMg = vitaminCMg; t.vitaminDUg = vitaminDUg; t.vitaminEMg = vitaminEMg
        t.vitaminKUg = vitaminKUg; t.vitaminB1Mg = vitaminB1Mg; t.vitaminB2Mg = vitaminB2Mg
        t.vitaminB3Mg = vitaminB3Mg; t.vitaminB5Mg = vitaminB5Mg; t.vitaminB6Mg = vitaminB6Mg
        t.vitaminB12Ug = vitaminB12Ug; t.folateUg = folateUg; t.ironMg = ironMg
        t.zincMg = zincMg; t.magnesiumMg = magnesiumMg; t.calciumMg = calciumMg
        t.seleniumUg = seleniumUg; t.copperUg = copperUg; t.omega3G = omega3G
        t.calories = calories; t.proteinG = proteinG; t.carbsG = carbsG; t.fatG = fatG
        t.fiberG = fiberG; t.sugarG = sugarG; t.sodiumMg = sodiumMg
        t.potassiumMg = potassiumMg; t.phosphorusMg = phosphorusMg
        t.clampNutrients()
        try? ctx.save()
        dismiss()
    }
}
