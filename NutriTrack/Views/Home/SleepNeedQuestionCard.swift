import SwiftUI
import CoreData

struct SleepNeedQuestionCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @ObservedObject var profile: UserProfile
    @AppStorage("hasAnsweredSleepNeed") private var hasAnswered = false
    @State private var isPicking = false

    var body: some View {
        if !hasAnswered {
            VStack(alignment: .leading, spacing: 10) {
                EyebrowText("One question, once")
                Text(SleepNeed.question)
                    .font(theme.display(.headline))
                    .foregroundStyle(theme.colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Your nights are compared with this. Until you answer, the app uses 8 h. You can change it in Profile.")
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Answer") { isPicking = true }
                    .buttonStyle(.themedOutline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
            .sheet(isPresented: $isPicking) {
                NumberWheelSheet(title: "Sleep need", value: profile.sleepNeed, range: SleepNeed.range,
                                 hasTenths: true, unit: "h", confirmTitle: "Save") { hours in
                    profile.sleepNeedHours = SleepNeed.resolved(hours)
                    try? ctx.save()
                    hasAnswered = true
                }
            }
        }
    }
}
