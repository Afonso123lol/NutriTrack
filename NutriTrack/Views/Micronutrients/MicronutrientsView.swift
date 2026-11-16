import SwiftUI

struct MicronutrientsView: View {
    let foodEntries: [FoodEntry]
    let supplementLogs: [SupplementLog]
    let templates: [SupplementTemplate]
    let profile: UserProfile

    private enum Period: String, CaseIterable {
        case today = "Today"
        case week = "Week"
    }

    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @State private var period = Period.today

    private func supNutrients(_ log: SupplementLog) -> NutritionAnalysis? {
        if let snapshot = log.snapshotNutrients { return snapshot }
        guard let t = templates.first(where: { $0.id?.uuidString == log.templateID }) else { return nil }
        return t.nutrientsScaled(by: log.doses)
    }

    private var currentBoard: MicronutrientBoard {
        switch period {
        case .today:
            let supplements = NutritionAnalysis.sum(supplementLogs.compactMap(supNutrients))
            let total = NutritionAnalysis.sum(foodEntries.map(\.analysis) + [supplements])
            return MicronutrientBoard.make(total: total, supplements: supplements, targets: profile.macroTargets,
                                           period: .today,
                                           hasLongSession: TrainingService.hasLongSession(on: Date(), in: ctx))
        case .week:
            let days = EvaluationService.completeDayIntakes(in: ctx)
            let average = WeekIntake.average(days)
            let weekDays = EvaluationService.foodWeekDays(in: ctx)
            let usual = weekDays.filter { !$0.hasLongSession }
            let sodium = usual.isEmpty ? nil
                : (mg: usual.map(\.sodiumMg).reduce(0, +) / Double(usual.count), leftOut: weekDays.count - usual.count)
            return MicronutrientBoard.make(total: average.total, supplements: average.supplements,
                                           targets: profile.macroTargets, period: .week(completeDays: days.count),
                                           hasLongSession: false, weekSodiumWithoutLongDays: sodium)
        }
    }

    var body: some View {
        let board = currentBoard
        ScrollView {
            LazyVStack(spacing: 14) {
                Picker("Period", selection: $period) {
                    ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        EyebrowText(period == .today ? "Key for your goal" : "Daily average, complete days")
                        Text(board.headline)
                            .font(theme.display(.title3))
                            .foregroundStyle(theme.colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                    ForEach(board.key) { reading in
                        NutrientRangeRow(reading: reading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .themedCard()

                ForEach(board.groups) { group in
                    DisclosureGroup {
                        VStack(spacing: 14) {
                            ForEach(group.readings) { reading in
                                NutrientRangeRow(reading: reading)
                            }
                        }
                        .padding(.top, 12)
                    } label: {
                        HStack {
                            Text(group.title)
                                .font(theme.body(.subheadline).weight(.medium))
                                .foregroundStyle(theme.colors.textPrimary)
                            Spacer()
                            Text(group.summary)
                                .font(theme.meta(.caption))
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }
                    .tint(theme.colors.textSecondary)
                    .themedCard()
                }

                Text("Reference values and upper levels from EFSA, and from DRI where EFSA has none. WHO for saturated fat, trans fat and sodium. Reference values describe habitual intake, so the verdict is given on the week, not the day. For magnesium, niacin, folate and vitamin A the upper level counts supplements only. Estimated from what you logged.")
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle("Micronutrients")
        .navigationBarTitleDisplayMode(.inline)
        .hidesCaptureButton()
    }
}
