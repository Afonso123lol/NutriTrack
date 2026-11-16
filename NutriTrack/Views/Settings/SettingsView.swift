import SwiftUI
import CoreData

struct SettingsView: View {
    @ObservedObject var profile: UserProfile
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @State private var weightKg: Double = 0
    @State private var plateDiameterCm: Double = 26
    @State private var sleepNeedHours: Double = SleepNeed.defaultHours
    @AppStorage("hasAnsweredSleepNeed") private var hasAnsweredSleepNeed = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    NavigationLink {
                        ThemePickerScreen(name: profile.name)
                    } label: {
                        LabeledContent {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(theme.colors.accent)
                                    .frame(width: 14, height: 14)
                                Text(theme.name)
                                    .foregroundStyle(theme.colors.textSecondary)
                            }
                        } label: {
                            settingsLabel("paintpalette.fill", "Theme")
                        }
                    }
                }
                .listRowBackground(theme.colors.surface)

                Section("About you") {
                    profileRow("person.fill", "Name", value: profile.name ?? "—")
                    HStack(spacing: 10) {
                        settingsIcon("calendar")
                        DateWheelField(title: profile.birthDate == nil ? "Birth date · \(profile.age) years" : "Birth date",
                                       date: profile.birthDate, range: BirthDate.allowedRange(now: Date()),
                                       suggested: Calendar.current.date(byAdding: .year, value: -Int(max(profile.age, 14)),
                                                                        to: Date()) ?? Date()) { date in
                            profile.setBirthDate(date)
                            try? ctx.save()
                        }
                    }
                    if profile.birthDate != nil {
                        profileRow("number", "Age", value: "\(profile.age) years")
                    }
                    profileRow("figure.stand", "Sex", value: profile.sexEnum.displayName)
                    profileRow("ruler.fill", "Height", value: String(format: "%.0f cm", profile.heightCm))
                }
                .listRowBackground(theme.colors.surface)

                Section("Update") {
                    HStack(spacing: 10) {
                        settingsIcon("scalemass.fill")
                        NumberWheelField(title: "Weight", value: $weightKg, range: 30...300, hasTenths: true, unit: "kg")
                    }
                    HStack(spacing: 10) {
                        settingsIcon("circle.dashed")
                        NumberWheelField(title: "Plate diameter", value: $plateDiameterCm, range: 18...34, unit: "cm")
                    }
                    HStack(spacing: 10) {
                        settingsIcon("bed.double.fill")
                        NumberWheelField(title: "Sleep need", value: $sleepNeedHours, range: SleepNeed.range,
                                         hasTenths: true, unit: "h")
                    }
                    NavigationLink {
                        CalibrationView(profile: profile)
                    } label: {
                        LabeledContent {
                            Text(profile.yellowModeValue.label)
                                .foregroundStyle(theme.colors.textSecondary)
                        } label: {
                            settingsLabel("flag.checkered", "Yellow days")
                        }
                    }
                    NavigationLink {
                        GoalsView(profile: profile)
                    } label: {
                        LabeledContent {
                            Text(profile.goalEnum.choiceName)
                                .foregroundStyle(theme.colors.textSecondary)
                        } label: {
                            settingsLabel("target", "Goal and targets")
                        }
                    }
                }
                .listRowBackground(theme.colors.surface)

                Section("Sync") {
                    LabeledContent {
                        if let engine = SyncEngine.shared {
                            SyncStatusValue(queue: engine.queue)
                        } else {
                            Text(SyncStatusText.describe(isConfigured: false, pendingCount: 0, lastSentAt: nil, lastError: nil) { _ in "" })
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    } label: {
                        settingsLabel("arrow.triangle.2.circlepath", "Server")
                    }
                }
                .listRowBackground(theme.colors.surface)

                Section("Data sources") {
                    Link(destination: OpenFoodFacts.siteURL) {
                        settingsLabel("barcode", OpenFoodFacts.attribution)
                    }
                }
                .listRowBackground(theme.colors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { saveBar }
            .navigationTitle("Profile")
            .onAppear {
                weightKg = profile.weightKg
                plateDiameterCm = profile.plateDiameterCm
                sleepNeedHours = profile.sleepNeed
            }
        }
    }

    private var saveBar: some View {
        Button {
            guard !saved else { return }
            save()
            withAnimation(.easeInOut(duration: 0.2)) { saved = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeInOut(duration: 0.2)) { saved = false }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: saved ? "checkmark.circle.fill" : "checkmark.circle")
                Text(saved ? "Saved" : "Save changes")
            }
        }
        .buttonStyle(.themedPrimary(fill: saved ? theme.colors.success : theme.colors.accent))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.colors.background)
    }

    private func settingsIcon(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.caption)
            .foregroundStyle(theme.colors.onAccent)
            .frame(width: 26, height: 26)
            .background(
                theme.colors.accent,
                in: RoundedRectangle(cornerRadius: theme.shape.controlRadius * 0.6, style: .continuous)
            )
            .accessibilityHidden(true)
    }

    private func settingsLabel(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            settingsIcon(icon)
            Text(text)
                .foregroundStyle(theme.colors.textPrimary)
        }
    }

    private func profileRow(_ icon: String, _ label: String, value: String) -> some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(theme.colors.textSecondary)
        } label: {
            settingsLabel(icon, label)
        }
    }

    private func save() {
        profile.weightKg = weightKg
        profile.plateDiameterCm = plateDiameterCm
        hasAnsweredSleepNeed = true
        profile.sleepNeedHours = SleepNeed.resolved(sleepNeedHours)
        try? ctx.save()
    }
}

private struct SyncStatusValue: View {
    @ObservedObject var queue: SyncQueue
    @Environment(\.theme) private var theme

    var body: some View {
        Text(SyncStatusText.describe(isConfigured: true, pendingCount: queue.pendingCount,
                                     lastSentAt: queue.state.lastSentAt, lastError: queue.state.lastError) {
            $0.formatted(date: .omitted, time: .shortened)
        })
        .font(theme.body(.footnote))
        .foregroundStyle(queue.state.lastError == nil ? theme.colors.textSecondary : theme.colors.warning)
        .multilineTextAlignment(.trailing)
        .lineLimit(3)
    }
}
