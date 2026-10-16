import SwiftUI
import CoreData

struct LogStrengthSheet: View {
    let plannedID: UUID?
    let exercises: [StrengthExercise]
    let sets: Int
    let reserve: ClosedRange<Int>
    let estimatedMinutes: Double

    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [SetDraft] = []
    @State private var steps: [String: StrengthStep] = [:]
    @State private var effort = 5.0
    @State private var date = Date()

    struct SetDraft: Identifiable {
        let id = UUID()
        let exercise: String
        var loadKg: Double
        var reps: Int
        var rir: Int
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(exercises) { exercise in
                    Section {
                        ForEach($drafts) { $draft in
                            if draft.exercise == exercise.key {
                                setRow($draft, usesLoad: exercise.usesLoad)
                            }
                        }
                    } header: {
                        Text(exercise.name)
                    } footer: {
                        Text("\(exercise.cue) \(steps[exercise.key]?.text ?? "")")
                    }
                    .listRowBackground(theme.colors.surface)
                }

                Section {
                    DatePicker("When", selection: $date, in: ...Date())
                    LabeledContent("Effort of the whole session", value: String(format: "%.0f / 10", effort))
                    Slider(value: $effort, in: 0...10, step: 1)
                        .accessibilityLabel("Effort from 0 to 10")
                } footer: {
                    Text("Aim for \(StrengthProgram.repRange.lowerBound)–\(StrengthProgram.repRange.upperBound) reps and stop with \(reserve.lowerBound)–\(reserve.upperBound) reps in reserve. Leave reps at 0 for a set you skipped.")
                }
                .listRowBackground(theme.colors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Log strength")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear(perform: prepare)
        }
    }

    private func setRow(_ draft: Binding<SetDraft>, usesLoad: Bool) -> some View {
        HStack(spacing: 12) {
            if usesLoad {
                TextField("kg", value: draft.loadKg, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .frame(width: 56)
                Text("kg")
                    .foregroundStyle(theme.colors.textSecondary)
            }
            Stepper(value: draft.reps, in: 0...40) {
                Text("\(draft.wrappedValue.reps) reps")
                    .font(theme.number(.subheadline))
                    .foregroundStyle(theme.colors.textPrimary)
            }
            Picker("In reserve", selection: draft.rir) {
                ForEach(0...6, id: \.self) { Text("\($0) left").tag($0) }
            }
            .labelsHidden()
        }
    }

    private func prepare() {
        guard drafts.isEmpty else { return }
        for exercise in exercises {
            let last = TrainingService.lastSets(exercise: exercise.key, in: ctx)
            let step = StrengthProgram.next(after: last, reserve: reserve, usesLoad: exercise.usesLoad)
            steps[exercise.key] = step
            var load = last.map(\.loadKg).max() ?? 0
            var reps = last.map(\.reps).min() ?? StrengthProgram.repRange.lowerBound
            switch step {
            case .addLoad(let kg):
                load = kg
                reps = StrengthProgram.repRange.lowerBound
            case .addRep:
                reps = min(reps + 1, StrengthProgram.repRange.upperBound)
            case .hold, .harderVariation:
                break
            }
            for _ in 0..<max(sets, 1) {
                drafts.append(SetDraft(exercise: exercise.key, loadKg: load, reps: reps, rir: reserve.upperBound))
            }
        }
    }

    private func save() {
        let inputs = drafts.map { StrengthSetInput(exercise: $0.exercise, loadKg: $0.loadKg, reps: $0.reps, rir: $0.rir) }
        TrainingService.logStrength(sets: inputs, durationMin: estimatedMinutes, rpe: Int(effort),
                                    plannedSessionID: plannedID, at: date, in: ctx)
        dismiss()
    }
}
