import SwiftUI

struct CheckInCard: View {
    @Environment(\.theme) private var theme
    let bedtime: Date?
    let onSave: (CheckInAnswers) -> Void

    @State private var answers: CheckInAnswers
    @State private var isPickingWakeTime = false
    private let openedAt: Date

    init(bedtime: Date?, now: Date = Date(), onSave: @escaping (CheckInAnswers) -> Void) {
        self.bedtime = bedtime
        self.onSave = onSave
        openedAt = now
        var initial = CheckInAnswers(wakeTime: now)
        initial.sleepHours = TimeInBed.prefill(bedtime: bedtime, wakeTime: now)
        _answers = State(initialValue: initial)
    }

    private var isTimeInBed: Bool {
        TimeInBed.hours(bedtime: bedtime, wakeTime: answers.wakeTime) != nil
    }

    private var wakeTimeText: String {
        answers.wakeTime.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "sunrise.fill")
                    .foregroundStyle(theme.colors.accent)
                    .accessibilityHidden(true)
                Text("Morning check-in")
                    .font(theme.display(.headline))
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
            }

            ratingRow(title: "Energy", value: $answers.energy,
                      filledIcon: "bolt.fill", emptyIcon: "bolt", tint: theme.colors.accent)

            ratingRow(title: "Sleep quality", value: $answers.quality,
                      filledIcon: "moon.stars.fill", emptyIcon: "moon", tint: theme.colors.sleep)

            ratingRow(title: "Muscle soreness", value: $answers.soreness,
                      filledIcon: "circle.fill", emptyIcon: "circle", tint: theme.colors.warning,
                      scale: "1 none · 5 very sore")

            ratingRow(title: "Stress", value: $answers.stress,
                      filledIcon: "circle.fill", emptyIcon: "circle", tint: theme.colors.warning,
                      scale: "1 calm · 5 very stressed")

            VStack(alignment: .leading, spacing: 4) {
                Button { isPickingWakeTime = true } label: {
                    HStack(spacing: 8) {
                        Text("Woke up at")
                            .foregroundStyle(theme.colors.textPrimary)
                        Spacer()
                        Text(wakeTimeText)
                            .font(theme.number(.body))
                            .foregroundStyle(theme.colors.textPrimary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(theme.colors.textMuted)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Woke up at")
                .accessibilityValue(wakeTimeText)

                HoursSleptField(hours: $answers.sleepHours)

                if isTimeInBed {
                    Text("Time in bed. Actual sleep is a little less.")
                        .font(theme.body(.caption))
                        .foregroundStyle(theme.colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(theme.body(.subheadline))

            Toggle("I'm ill today", isOn: $answers.isSick)
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textPrimary)
            Toggle("Pain that changes how I walk", isOn: $answers.hasPain)
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textPrimary)

            Button("Save check-in") {
                onSave(answers)
            }
            .buttonStyle(.themedPrimary)
            .disabled(!answers.isComplete)
        }
        .themedCard()
        .sensoryFeedback(.selection, trigger: answers.energy)
        .sensoryFeedback(.selection, trigger: answers.quality)
        .sensoryFeedback(.selection, trigger: answers.soreness)
        .sensoryFeedback(.selection, trigger: answers.stress)
        .sheet(isPresented: $isPickingWakeTime) {
            DateWheelSheet(title: "Woke up at", date: answers.wakeTime,
                           range: Calendar.current.startOfDay(for: openedAt)...openedAt,
                           components: .hourAndMinute, confirmTitle: "Done") { picked in
                answers.wakeTime = picked
                answers.sleepHours = TimeInBed.prefill(bedtime: bedtime, wakeTime: picked)
            }
        }
    }

    private func ratingRow(title: String, value: Binding<Int>, filledIcon: String, emptyIcon: String,
                           tint: Color, scale: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            EyebrowText(title)
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { level in
                    Button {
                        withAnimation(.spring(duration: 0.25)) { value.wrappedValue = level }
                    } label: {
                        Image(systemName: value.wrappedValue >= level ? filledIcon : emptyIcon)
                            .font(.title3)
                            .foregroundStyle(value.wrappedValue >= level ? tint : theme.colors.textMuted)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("\(title), \(level) of 5")
                    .accessibilityAddTraits(value.wrappedValue == level ? .isSelected : [])
                }
            }
            if let scale {
                Text(scale)
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
    }
}
