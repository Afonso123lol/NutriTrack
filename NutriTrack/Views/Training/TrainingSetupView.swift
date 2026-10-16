import SwiftUI
import CoreData

struct TrainingSetupView: View {
    @ObservedObject var user: UserProfile
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var answers = Array(repeating: false, count: ScreeningGate.questions.count)
    @State private var weeklyMinutes = 0.0
    @State private var daysPerWeek = 3
    @State private var hasTreadmill = false
    @State private var hasBike = false
    @State private var hasGym = false
    @State private var hasHRMonitor = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(ScreeningGate.questions.indices, id: \.self) { index in
                        Toggle(isOn: $answers[index]) {
                            Text(ScreeningGate.questions[index])
                                .font(theme.body(.subheadline))
                                .foregroundStyle(theme.colors.textPrimary)
                        }
                    }
                } header: {
                    Text("Health check")
                } footer: {
                    Text("Switch on what applies to you. With any of them on, the app waits for you to talk to a doctor before it builds a plan. This is a short screening, not a diagnosis; the full questionnaire is the PAR-Q+ at eparmedx.com.")
                }
                .listRowBackground(theme.colors.surface)

                Section {
                    Stepper(value: $weeklyMinutes, in: 0...600, step: 15) {
                        LabeledContent("Exercise per week now", value: String(format: "%.0f min", weeklyMinutes))
                    }
                    Picker("Days you can train", selection: $daysPerWeek) {
                        ForEach(3...6, id: \.self) { Text("\($0) days").tag($0) }
                    }
                } header: {
                    Text("Where you are now")
                } footer: {
                    Text("Count walking for exercise, cycling, gym. The first weeks start from here, never below 75 minutes.")
                }
                .listRowBackground(theme.colors.surface)

                Section("What you have") {
                    Toggle("Treadmill with incline", isOn: $hasTreadmill)
                    Toggle("Bike or exercise bike", isOn: $hasBike)
                    Toggle("Gym or dumbbells", isOn: $hasGym)
                    Toggle("Heart-rate monitor", isOn: $hasHRMonitor)
                }
                .listRowBackground(theme.colors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Training setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let profile = TrainingService.profile(in: ctx) else { return }
        weeklyMinutes = profile.currentWeeklyMinutes
        daysPerWeek = min(max(Int(profile.daysPerWeek), 3), 6)
        hasTreadmill = profile.hasTreadmill
        hasBike = profile.hasBike
        hasGym = profile.hasGym
        hasHRMonitor = profile.hasHRMonitor
    }

    private func save() {
        let existing = TrainingService.profile(in: ctx)
        let profile = existing ?? TrainingProfile(context: ctx)
        if existing == nil {
            profile.id = UUID()
            profile.createdAt = Date()
        }
        let daysChanged = existing != nil && Int(profile.daysPerWeek) != daysPerWeek
        let hasFlag = answers.contains(true)
        if hasFlag != profile.screeningHasFlag { profile.doctorCleared = false }
        profile.screeningHasFlag = hasFlag
        profile.screeningAnsweredAt = Date()
        profile.currentWeeklyMinutes = weeklyMinutes
        profile.daysPerWeek = Int16(daysPerWeek)
        profile.hasTreadmill = hasTreadmill
        profile.hasBike = hasBike
        profile.hasGym = hasGym
        profile.hasHRMonitor = hasHRMonitor
        try? ctx.save()
        if daysChanged {
            TrainingService.regenerateWeek(user: user, in: ctx)
        } else {
            TrainingService.ensureWeek(user: user, in: ctx)
        }
        dismiss()
    }
}
