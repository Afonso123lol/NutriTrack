import SwiftUI
import CoreData

struct SleepDetailView: View {
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @ObservedObject var profile: UserProfile
    @State private var need: Double = SleepNeed.defaultHours
    @AppStorage("hasAnsweredSleepNeed") private var hasAnsweredSleepNeed = false

    var body: some View {
        let summary = TrainingService.sleepSummary(now: Date(), profile: profile, in: ctx)
        let lastNight = DailyCheckIn.on(Date(), in: ctx)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                card("Last night") {
                    if let hours = lastNight?.sleepHours, hours > 0 {
                        line("\(DayHeadline.hours(hours)) h of \(DayHeadline.hours(profile.sleepNeed)) h need", isMain: true)
                        if lastNight?.bedtime != nil {
                            note("Time in bed. Actual sleep is a little less.")
                        }
                    } else {
                        note("Check in this morning to see last night.")
                    }
                }

                card("Last 7 nights") {
                    if let average = summary.averageText {
                        line(average, isMain: true)
                        if let enough = summary.enoughNightsText { line(enough, isMain: false) }
                        if let quality = summary.averageQuality {
                            line(String(format: "Quality %.1f of 5", quality), isMain: false)
                        }
                    } else {
                        note("No nights logged this week yet.")
                    }
                }

                card("Bedtime regularity") {
                    if let regularity = summary.regularity {
                        line(regularity.text, isMain: true)
                        line("Band: \(regularity.band.text)", isMain: false)
                        note("Bands from Huang 2020, in adults aged 45 to 84 at cardiovascular risk.")
                    } else {
                        note("Tap the moon at bedtime on 5 of 7 nights to see how regular your bedtime is.")
                    }
                }

                card("Day energy by hours slept") {
                    if let bands = summary.energyByHours {
                        ForEach(bands, id: \.label) { band in
                            HStack {
                                Text(band.label)
                                    .font(theme.body(.subheadline))
                                    .foregroundStyle(theme.colors.textPrimary)
                                Spacer()
                                Text(band.averageEnergy.map { String(format: "%.1f of 5", $0) } ?? "—")
                                    .font(theme.number(.subheadline))
                                    .foregroundStyle(theme.colors.textPrimary)
                                Text("\(band.nights) nights")
                                    .font(theme.body(.caption))
                                    .foregroundStyle(theme.colors.textSecondary)
                                    .frame(width: 64, alignment: .trailing)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        note("From your own nights. Energy also depends on training, stress and caffeine.")
                    } else {
                        note("Shows after \(SleepSummary.nightsForEnergy) nights with an answer to the evening question.")
                    }
                }

                card("Sleep need") {
                    NumberWheelField(title: "Sleep need", value: $need, range: SleepNeed.range, hasTenths: true, unit: "h")
                    note("Your nights are compared with this. The app does not change it by itself. 7 h or more is the consensus for adults; people who train may need more.")
                }
            }
            .padding(16)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { need = profile.sleepNeed }
        .onChange(of: need) { _, value in
            guard SleepNeed.resolved(value) != profile.sleepNeed else { return }
            profile.sleepNeedHours = SleepNeed.resolved(value)
            hasAnsweredSleepNeed = true
            try? ctx.save()
        }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowText(title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func line(_ text: String, isMain: Bool) -> some View {
        Text(text)
            .font(isMain ? theme.display(.headline) : theme.body(.subheadline))
            .foregroundStyle(isMain ? theme.colors.textPrimary : theme.colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(theme.body(.caption))
            .foregroundStyle(theme.colors.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}
