import SwiftUI

struct BiometricsStepView: View {
    @Environment(\.theme) private var theme
    @Binding var name: String
    @Binding var birthDate: Date
    @Binding var sex: Sex
    @Binding var weightKg: Double
    @Binding var heightCm: Double
    @Binding var plateDiameterCm: Double
    let onNext: () -> Void

    private var isNameEmpty: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if let engine = SyncEngine.shared {
                    RestoreSection(engine: engine)
                }
                Section("About you") {
                    TextField("Name", text: $name)
                    DateWheelField(title: "Birth date", date: birthDate, range: BirthDate.allowedRange(now: Date()),
                                   suggested: birthDate) { birthDate = $0 }
                    Picker("Sex", selection: $sex) {
                        ForEach(Sex.allCases) { s in Text(s.displayName).tag(s) }
                    }
                }
                .listRowBackground(theme.colors.surface)
                Section("Body metrics") {
                    NumberWheelField(title: "Weight", value: $weightKg, range: 30...300, hasTenths: true, unit: "kg")
                    NumberWheelField(title: "Height", value: $heightCm, range: 130...220, unit: "cm")
                }
                .listRowBackground(theme.colors.surface)
                Section {
                    NumberWheelField(title: "Plate diameter", value: $plateDiameterCm, range: 18...34, unit: "cm")
                } footer: {
                    Text("Used to calibrate portion sizes in AI analysis. Measure your usual plate.")
                }
                .listRowBackground(theme.colors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button("Next", action: onNext)
                    .buttonStyle(.themedPrimary)
                    .disabled(isNameEmpty)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(theme.colors.background)
            }
            .navigationTitle("Your profile")
        }
    }
}
