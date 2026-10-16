import Foundation

nonisolated struct StrengthExercise: Equatable, Identifiable, Sendable {
    let key: String
    let name: String
    let pattern: String
    let usesLoad: Bool
    let cue: String

    var id: String { key }
}

nonisolated struct SetResult: Equatable, Sendable {
    let loadKg: Double
    let reps: Int
    let rir: Int
}

nonisolated enum StrengthStep: Equatable, Sendable {
    case hold
    case addRep
    case addLoad(kg: Double)
    case harderVariation

    var text: String {
        switch self {
        case .hold: return "Start light: stop with 3–4 reps in reserve."
        case .addRep: return "Same load, one more rep per set."
        case .addLoad(let kg): return String(format: "Go up to %g kg and start again from 10 reps.", kg)
        case .harderVariation: return "Top of the range: slow the lowering phase or add a pause."
        }
    }
}

nonisolated enum StrengthProgram {
    static let repRange = 10...15
    static let loadIncrease = 0.05
    static let smallestIncrement = 0.5
    static let longestSetForEstimate = 10

    private static let gym = [
        StrengthExercise(key: "goblet-box-squat", name: "Goblet squat to a box", pattern: "squat", usesLoad: true,
                         cue: "Sit back to the box, stand up without rocking."),
        StrengthExercise(key: "dumbbell-rdl", name: "Romanian deadlift with dumbbells", pattern: "hinge", usesLoad: true,
                         cue: "Hips back, flat back, weights close to the legs."),
        StrengthExercise(key: "step-up", name: "Low step-up", pattern: "step", usesLoad: true,
                         cue: "Step of 15–20 cm, push through the whole foot, lower slowly."),
        StrengthExercise(key: "incline-push-up", name: "Incline push-up", pattern: "push", usesLoad: false,
                         cue: "Hands on a bench or bar, body in one line."),
        StrengthExercise(key: "seated-row", name: "Seated row", pattern: "pull", usesLoad: true,
                         cue: "Pull the elbows back, chest tall, no swinging."),
        StrengthExercise(key: "farmer-carry", name: "Farmer carry", pattern: "core", usesLoad: true,
                         cue: "Walk tall for 30–40 steps; count each 10 steps as one rep.")
    ]

    private static let home = [
        StrengthExercise(key: "box-sit-to-stand", name: "Sit to stand from a chair", pattern: "squat", usesLoad: false,
                         cue: "Arms crossed, stand up without using your hands."),
        StrengthExercise(key: "glute-bridge", name: "Glute bridge", pattern: "hinge", usesLoad: false,
                         cue: "Feet flat, lift the hips, pause one second at the top."),
        StrengthExercise(key: "step-up", name: "Low step-up", pattern: "step", usesLoad: false,
                         cue: "Step of 15–20 cm, push through the whole foot, lower slowly."),
        StrengthExercise(key: "incline-push-up", name: "Incline push-up", pattern: "push", usesLoad: false,
                         cue: "Hands on a table or counter, body in one line."),
        StrengthExercise(key: "backpack-row", name: "Backpack row", pattern: "pull", usesLoad: true,
                         cue: "One hand on a chair, pull a loaded backpack to the hip."),
        StrengthExercise(key: "dead-bug", name: "Dead bug", pattern: "core", usesLoad: false,
                         cue: "Lower back on the floor, move opposite arm and leg slowly.")
    ]

    static func exercises(hasGym: Bool) -> [StrengthExercise] {
        hasGym ? gym : home
    }

    static func exercise(key: String) -> StrengthExercise? {
        (gym + home).first { $0.key == key }
    }

    static func targetReserve(weekNumber: Int) -> ClosedRange<Int> {
        weekNumber <= 4 ? 3...4 : 2...3
    }

    static func next(after sets: [SetResult], reserve: ClosedRange<Int>, usesLoad: Bool) -> StrengthStep {
        guard !sets.isEmpty else { return .hold }
        let load = sets.map(\.loadKg).max() ?? 0
        let raised = max((load * (1 + loadIncrease) / smallestIncrement).rounded() * smallestIncrement,
                         load + smallestIncrement)
        let muchInReserve = sets.contains { $0.rir >= reserve.upperBound + 2 }
        let topOfRange = sets.allSatisfy { $0.reps >= repRange.upperBound && $0.rir >= reserve.lowerBound }
        guard muchInReserve || topOfRange else { return .addRep }
        return usesLoad && load > 0 ? .addLoad(kg: raised) : .harderVariation
    }

    static func estimatedOneRepMax(loadKg: Double, reps: Int) -> Double? {
        guard loadKg > 0, reps > 0, reps <= longestSetForEstimate else { return nil }
        return loadKg * (1 + Double(reps) / 30)
    }
}
