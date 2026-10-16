import SwiftUI
import CoreData

struct GoalsView: View {
    @ObservedObject var profile: UserProfile
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(entity: TargetSnapshot.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \TargetSnapshot.weekStart, ascending: false)])
    private var snapshots: FetchedResults<TargetSnapshot>

    @State private var goal: Goal = .maintain
    @State private var ratePercent = 0.0
    @State private var activityFactor = ExpenditureEstimator.defaultActivityFactor
    @State private var saved = false

    private var snapshot: TargetSnapshot? { snapshots.first }
    private var weightKg: Double { snapshot?.trendWeightKg ?? profile.weightKg }
    private var bmi: Double { BodyMetrics.bmi(weightKg: weightKg, heightCm: profile.heightCm) }
    private var direction: GoalDirection { goal.direction }
    private var option: RateOption? { TargetPlanner.rateOption(direction: direction, bmi: bmi) }

    private var tdee: Double {
        if let snapshot, snapshot.tdeeSource == "adaptive" { return snapshot.tdee }
        let resting = BodyMetrics.restingRate(sex: profile.sexEnum, age: Int(profile.age),
                                              weightKg: weightKg, heightCm: profile.heightCm)
        return ExpenditureEstimator.formula(restingRate: resting, activityFactor: activityFactor)
    }

    private var preview: PlannedTargets {
        TargetPlanner.plan(TargetInput(sex: profile.sexEnum, age: Int(profile.age), weightKg: weightKg,
                                       heightCm: profile.heightCm, direction: direction,
                                       ratePercent: ratePercent, tdee: tdee,
                                       highProtein: goal.prefersHighProtein))
    }

    var body: some View {
        let preview = self.preview
        ScrollView {
            LazyVStack(spacing: 14) {
                goalCard
                paceCard
                targetsCard(preview)
                whyCard(preview)
                Text("General guidance, not medical advice. Talk to a doctor before a deficit if your BMI is 35 or more, or 30 or more with a chronic condition or medication; and at any time with dizziness, fainting, palpitations, chest pain, or strong pain on the right side of the abdomen.")
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .hidesCaptureButton()
        .safeAreaInset(edge: .bottom) {
            Button {
                save()
            } label: {
                Label(saved ? "Saved" : "Save goal", systemImage: saved ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .buttonStyle(.themedPrimary(fill: saved ? theme.colors.success : theme.colors.accent))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.colors.background)
        }
        .onAppear {
            goal = profile.goalEnum.offeredEquivalent
            ratePercent = profile.weeklyRatePercent
            activityFactor = profile.activityFactor > 0 ? profile.activityFactor : ExpenditureEstimator.defaultActivityFactor
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowText("Goal")
            Picker("Goal", selection: $goal) {
                ForEach(Goal.offered) { Text($0.shortName).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: goal) { _, _ in ratePercent = 0 }
            Text(goal.choiceDescription)
                .font(theme.body(.caption))
                .foregroundStyle(theme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if direction != .maintain, option == nil {
                Text(direction == .gain
                     ? "Gaining is offered below a BMI of 25. Your targets stay at maintenance."
                     : "Losing is not offered below a BMI of 18.5. Your targets stay at maintenance.")
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.warning)
            }
            EyebrowText("Activity outside training")
            Picker("Activity", selection: $activityFactor) {
                Text("Low").tag(1.4)
                Text("Moderate").tag(1.55)
                Text("High").tag(1.75)
            }
            .pickerStyle(.segmented)
            Text("Used only until the app has measured your real expenditure.")
                .font(theme.body(.caption))
                .foregroundStyle(theme.colors.textSecondary)
        }
        .themedCard()
    }

    @ViewBuilder
    private var paceCard: some View {
        if let option {
            let shown = ratePercent > 0 ? min(ratePercent, option.maximumPercent) : option.defaultPercent
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    EyebrowText("Pace")
                    Spacer()
                    Text(String(format: "%.2f%% per week · %.2f kg", shown, shown / 100 * weightKg))
                        .font(theme.number(.subheadline))
                        .foregroundStyle(theme.colors.textPrimary)
                }
                Slider(value: Binding(get: { shown }, set: { ratePercent = $0 }),
                       in: 0.1...option.maximumPercent, step: 0.05)
                    .accessibilityLabel("Pace, percent of body weight per week")
                Text(String(format: "Suggested: %.2f%%. Faster than %.2f%% is not offered at your BMI.",
                            option.defaultPercent, option.maximumPercent))
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .themedCard()
        }
    }

    private func targetsCard(_ preview: PlannedTargets) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowText("Daily targets")
            row("Calories", String(format: "%.0f kcal", preview.calories))
            row("Protein", String(format: "%.0f g", preview.proteinG))
            row("Carbohydrates", String(format: "%.0f g", preview.carbsG))
            row("Fat", String(format: "%.0f g", preview.fatG))
            if let note = limitNote(preview.limitedBy.rawValue) {
                Text(note)
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.warning)
            }
        }
        .themedCard()
    }

    private func whyCard(_ preview: PlannedTargets) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowText("Why these numbers")
            row("Estimated expenditure", String(format: "%.0f kcal", tdee))
            Text(snapshot?.tdeeSource == "adaptive"
                 ? "Measured from what you ate and how your weight moved over the last 4 weeks. Expect it to be off by 200–300 kcal."
                 : "From a formula for now. It switches to your measured expenditure with 20 days closed by you in the last 28 (at least 4 each week) and 8 weigh-ins.")
                .font(theme.body(.caption))
                .foregroundStyle(theme.colors.textSecondary)
            row("Trend weight", String(format: "%.1f kg", weightKg))
            if let snapshot {
                row("Measured pace", snapshot.hasMeasuredRate
                    ? String(format: "%+.2f kg per week", snapshot.measuredRateKgPerWeek) : "Not enough weigh-ins")
                row("Days closed by you", "\(snapshot.completeDays) of \(ExpenditureEstimator.minimumCompleteDays)")
                row("Weigh-ins in 4 weeks", "\(snapshot.weighIns) of \(WeightTrend.minimumWeighIns)")
                if let note = limitNote(snapshot.limitedBy ?? "") , snapshot.limitedBy == "tooFast" || snapshot.limitedBy == "fastLoss" {
                    Text(note)
                        .font(theme.body(.caption))
                        .foregroundStyle(theme.colors.warning)
                }
            }
        }
        .themedCard()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
            Text(value)
                .font(theme.number(.subheadline))
                .foregroundStyle(theme.colors.textSecondary)
        }
    }

    private func limitNote(_ limit: String) -> String? {
        switch limit {
        case "deficitShare": return "The deficit is capped at a share of your expenditure, so the real pace is slower than the one you picked."
        case "fatMass": return "The deficit is capped by your estimated fat mass."
        case "absoluteRate": return "The deficit is capped at 1.5 kg per week."
        case "calorieFloor": return "The target is at the calorie floor, so the real pace is slower than the one you picked."
        case "surplusShare": return "The surplus is capped at 15% of your expenditure."
        case "blocked": return "This goal is not offered for your profile; targets are at maintenance."
        case "fastLoss": return "You have been losing more than 1% per week for three updates. The target was raised by 10%."
        case "tooFast": return "You have been losing more than 1.5 kg per week. The target is at maintenance; losing this fast raises the risk of gallstones. Talk to a doctor if it was not intended."
        default: return nil
        }
    }

    private func save() {
        if profile.goalEnum.offeredEquivalent != goal || profile.weeklyRatePercent != ratePercent {
            profile.goalChangedAt = Date()
        }
        if profile.goalEnum.offeredEquivalent != goal { profile.goalEnum = goal }
        profile.weeklyRatePercent = ratePercent
        profile.activityFactor = activityFactor
        try? ctx.save()
        TargetService.refresh(profile: profile, force: true, in: ctx)
        withAnimation(.easeInOut(duration: 0.2)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) { saved = false }
        }
    }
}
