import SwiftUI
import CoreData

struct LogAerobicSheet: View {
    let plannedID: UUID?

    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var modality: Modality
    @State private var duration: Double
    @State private var effort = 3.0
    @State private var elevation = 0.0
    @State private var distance = 0.0
    @State private var heartRate = 0.0
    @State private var pack = 0.0
    @State private var note = ""
    @State private var date = Date()

    init(plannedID: UUID?, modality: Modality, minutes: Double) {
        self.plannedID = plannedID
        _modality = State(initialValue: Modality.aerobic.contains(modality) ? modality : .walk)
        _duration = State(initialValue: max(minutes, 5))
    }

    private var effortHint: String {
        switch Int(effort) {
        case ...4: return "Easy: you can speak in full sentences."
        case 5...6: return "Moderate: short sentences only."
        default: return "Hard: a few words at a time. Base training should stay easy."
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    Picker("Type", selection: $modality) {
                        ForEach(Modality.aerobic, id: \.self) { Text($0.label).tag($0) }
                    }
                    Stepper(value: $duration, in: 5...600, step: 5) {
                        LabeledContent("Duration", value: String(format: "%.0f min", duration))
                    }
                    DatePicker("When", selection: $date, in: ...Date())
                }
                .listRowBackground(theme.colors.surface)

                Section {
                    LabeledContent("Effort", value: String(format: "%.0f / 10", effort))
                    Slider(value: $effort, in: 0...10, step: 1)
                        .accessibilityLabel("Effort from 0 to 10")
                } footer: {
                    Text(effortHint)
                }
                .listRowBackground(theme.colors.surface)

                Section("Optional") {
                    numberField("Elevation gain (m)", value: $elevation)
                    numberField("Distance (km)", value: $distance)
                    numberField("Average heart rate", value: $heartRate)
                    numberField("Pack weight (kg)", value: $pack)
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }
                .listRowBackground(theme.colors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Log session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        TrainingService.logAerobic(modality: modality, durationMin: duration, rpe: Int(effort),
                                                   elevationGainM: elevation, distanceKm: distance,
                                                   avgHR: Int(heartRate), packKg: pack, note: note,
                                                   plannedSessionID: plannedID, at: date, in: ctx)
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
}
