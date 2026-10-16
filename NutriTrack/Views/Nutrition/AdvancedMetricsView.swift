import SwiftUI

struct AdvancedMetricsView: View {
    @Environment(\.theme) private var theme
    let total: NutritionAnalysis

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                row("Net carbs", total.netCarbsG, "g")
                row("Sugar", total.sugarG, "g")
                row("Fiber", total.fiberG, "g")
                row("Saturated fat", total.saturatedFatG, "g")
                row("Monounsaturated fat", total.monounsaturatedFatG ?? 0, "g")
                row("Polyunsaturated fat", total.polyunsaturatedFatG ?? 0, "g")
                row("Trans fat", total.transFatG ?? 0, "g")
                row("Omega-3", total.omega3G, "g")
                row("Sodium", total.sodiumMg, "mg")
                row("Potassium", total.potassiumMg, "mg")
                if let alcohol = total.alcoholG, alcohol > 0 { row("Alcohol", alcohol, "g") }
            }
            .themedCard()
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle("Advanced metrics")
        .navigationBarTitleDisplayMode(.inline)
        .hidesCaptureButton()
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
