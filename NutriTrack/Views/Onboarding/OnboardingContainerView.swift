import SwiftUI
import CoreData

struct OnboardingContainerView: View {
    @Environment(\.managedObjectContext) private var ctx
    @State private var step = 0
    @State private var name = ""
    @State private var birthDate = BirthDate.suggested(now: Date())
    @State private var sex: Sex = .male
    @State private var weightKg = 75.0
    @State private var heightCm = 175.0
    @State private var plateDiameterCm = 26.0
    @State private var goal: Goal = .maintain

    var body: some View {
        Group {
            switch step {
            case 0:
                BiometricsStepView(
                    name: $name, birthDate: $birthDate, sex: $sex,
                    weightKg: $weightKg, heightCm: $heightCm,
                    plateDiameterCm: $plateDiameterCm
                ) { advance(to: 1) }
                .transition(.move(edge: .leading).combined(with: .opacity))
            case 1:
                GoalStepView(goal: $goal) { advance(to: 2) }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            default:
                ThemeStepView(name: name, onComplete: saveProfile)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private func advance(to next: Int) {
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }

    private func saveProfile() {
        let p = UserProfile(context: ctx)
        p.id = UUID()
        p.name = name.trimmingCharacters(in: .whitespaces)
        p.setBirthDate(birthDate)
        p.sexEnum = sex
        p.weightKg = weightKg
        p.heightCm = heightCm
        p.plateDiameterCm = plateDiameterCm
        p.goalEnum = goal
        p.createdAt = Date()
        p.activityFactor = ExpenditureEstimator.defaultActivityFactor
        try? ctx.save()
        TargetService.refresh(profile: p, in: ctx)
    }
}
