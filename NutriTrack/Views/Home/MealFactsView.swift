import SwiftUI

struct MealFactsView: View {
    @Environment(\.theme) private var theme
    let analysis: NutritionAnalysis

    var body: some View {
        Grid(horizontalSpacing: 10) {
            GridRow {
                MetricTile(label: "Protein", value: String(format: "%.0f", analysis.proteinG), unit: "g")
                MetricTile(label: "Carbs", value: String(format: "%.0f", analysis.carbsG), unit: "g")
                MetricTile(label: "Fat", value: String(format: "%.0f", analysis.fatG), unit: "g")
            }
        }

        group("Carbs and fats") {
            row("Net carbs", analysis.netCarbsG, "g")
            row("Fiber", analysis.fiberG, "g")
            row("Sugar", analysis.sugarG, "g")
            row("Saturated fat", analysis.saturatedFatG, "g")
            row("Monounsaturated fat", analysis.monounsaturatedFatG ?? 0, "g")
            row("Polyunsaturated fat", analysis.polyunsaturatedFatG ?? 0, "g")
            row("Trans fat", analysis.transFatG ?? 0, "g")
            row("Omega-3", analysis.omega3G, "g")
            if let alcohol = analysis.alcoholG, alcohol > 0 { row("Alcohol", alcohol, "g") }
        }

        group("Minerals") {
            row("Sodium", analysis.sodiumMg, "mg")
            row("Potassium", analysis.potassiumMg, "mg")
            row("Calcium", analysis.calciumMg, "mg")
            row("Iron", analysis.ironMg, "mg")
            row("Zinc", analysis.zincMg, "mg")
            row("Magnesium", analysis.magnesiumMg, "mg")
            row("Phosphorus", analysis.phosphorusMg, "mg")
            row("Selenium", analysis.seleniumUg, "µg")
            row("Copper", analysis.copperUg, "µg")
        }

        group("Vitamins") {
            row("Vitamin A", analysis.vitaminAUg ?? 0, "µg")
            row("Vitamin C", analysis.vitaminCMg, "mg")
            row("Vitamin D", analysis.vitaminDUg, "µg")
            row("Vitamin E", analysis.vitaminEMg, "mg")
            row("Vitamin K", analysis.vitaminKUg, "µg")
            row("B1 (Thiamine)", analysis.vitaminB1Mg, "mg")
            row("B2 (Riboflavin)", analysis.vitaminB2Mg, "mg")
            row("B3 (Niacin)", analysis.vitaminB3Mg, "mg")
            row("B5 (Pantothenic)", analysis.vitaminB5Mg, "mg")
            row("B6", analysis.vitaminB6Mg, "mg")
            row("B12", analysis.vitaminB12Ug, "µg")
            row("Folate (B9)", analysis.folateUg, "µg")
        }
    }

    private func group<Rows: View>(_ title: String, @ViewBuilder rows: () -> Rows) -> some View {
        let content = rows()
        return DisclosureGroup {
            VStack(spacing: 6) {
                content
            }
            .padding(.top, 10)
        } label: {
            Text(title)
                .font(theme.body(.subheadline).weight(.medium))
                .foregroundStyle(theme.colors.textPrimary)
        }
        .tint(theme.colors.textSecondary)
        .themedCard()
    }

    private func row(_ label: String, _ value: Double, _ unit: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textPrimary)
            NutrientInfoButton(label: label)
            Spacer()
            Text("\(NutrientReading.short(value)) \(unit)")
                .font(theme.number(.subheadline))
                .foregroundStyle(theme.colors.textSecondary)
        }
    }
}
