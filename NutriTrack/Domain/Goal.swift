nonisolated enum Goal: String, CaseIterable, Identifiable, Sendable {
    case gainWeight
    case gainMuscle
    case recomp
    case loseFat
    case maintain

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gainWeight: return "Gain Weight"
        case .gainMuscle: return "Gain Muscle"
        case .recomp: return "Recomposition"
        case .loseFat: return "Lose Fat"
        case .maintain: return "Maintain"
        }
    }

    static let offered: [Goal] = [.loseFat, .maintain, .recomp, .gainMuscle]

    var offeredEquivalent: Goal { self == .gainWeight ? .gainMuscle : self }

    var prefersHighProtein: Bool { self == .recomp }

    var shortName: String {
        switch self {
        case .loseFat: return "Lose fat"
        case .maintain: return "Maintain"
        case .recomp: return "Recomp"
        case .gainWeight, .gainMuscle: return "Gain"
        }
    }

    var choiceName: String {
        switch self {
        case .loseFat: return "Lose fat"
        case .maintain: return "Maintain"
        case .recomp: return "Recomposition"
        case .gainWeight, .gainMuscle: return "Gain"
        }
    }

    var choiceDescription: String {
        switch self {
        case .loseFat: return "About 0.5% of your body weight per week, protein kept high"
        case .maintain: return "Eat at your expenditure"
        case .recomp: return "Eat at your expenditure with protein as high as when cutting; for losing fat and gaining muscle while training"
        case .gainWeight, .gainMuscle: return "About 0.25% per week; offered below a BMI of 25"
        }
    }

    var direction: GoalDirection {
        switch self {
        case .loseFat: return .lose
        case .gainWeight, .gainMuscle: return .gain
        case .recomp, .maintain: return .maintain
        }
    }
}
