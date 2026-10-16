import SwiftUI

struct CheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profile: UserProfile
    let bedtime: Date?
    let onSave: (CheckInAnswers) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SleepNeedQuestionCard(profile: profile)
                CheckInCard(bedtime: bedtime) { answers in
                    onSave(answers)
                    dismiss()
                }
            }
            .padding(16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
