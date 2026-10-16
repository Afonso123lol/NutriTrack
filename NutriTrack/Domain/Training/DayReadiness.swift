import Foundation

nonisolated enum DayColor: String, Sendable {
    case green
    case yellow
    case red
    case unknown

    var isBad: Bool { self == .yellow || self == .red }

    var label: String {
        switch self {
        case .unknown: return "No check-in"
        case .green: return "Good to go"
        case .yellow: return "Take it easy"
        case .red: return "Rest day"
        }
    }
}

nonisolated struct DayState: Sendable {
    let energy: Int?
    let sleepHours: Double?
    let isSick: Bool
    let hasPain: Bool
    let energyBaseline: [Int]
}

nonisolated enum DayReason: Equatable, Sendable {
    case ill
    case pain
    case shortNight
    case lowEnergy(Int)
    case belowUsualEnergy

    var text: String {
        switch self {
        case .ill: return "You marked yourself ill."
        case .pain: return "You marked pain that changes how you walk."
        case .shortNight: return "Short night: the session may feel harder, mostly later in the day."
        case let .lowEnergy(value): return "Energy is \(value) of 5."
        case .belowUsualEnergy: return "Energy is below your usual."
        }
    }
}

nonisolated enum DayReadiness {
    static let minimumBaselineDays = 14
    static let minimumSpread = 1.0
    static let yellowSleepHours = 6.0
    static let yellowEnergy = 2

    static func color(_ state: DayState) -> DayColor {
        let reasons = reasons(state)
        if reasons.contains(.ill) || reasons.contains(.pain) { return .red }
        return reasons.isEmpty ? .green : .yellow
    }

    static func reasons(_ state: DayState) -> [DayReason] {
        var reasons: [DayReason] = []
        if state.isSick { reasons.append(.ill) }
        if state.hasPain { reasons.append(.pain) }
        if reasons.isEmpty {
            if let sleep = state.sleepHours, sleep > 0, sleep <= yellowSleepHours { reasons.append(.shortNight) }
            if let energy = state.energy, energy > 0 {
                if energy <= yellowEnergy {
                    reasons.append(.lowEnergy(energy))
                } else if isBelowUsual(energy, baseline: state.energyBaseline) {
                    reasons.append(.belowUsualEnergy)
                }
            }
        }
        return reasons
    }

    static func isBelowUsual(_ energy: Int, baseline: [Int]) -> Bool {
        guard baseline.count >= minimumBaselineDays else { return false }
        let values = baseline.map(Double.init)
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        let spread = max(variance.squareRoot(), minimumSpread)
        return Double(energy) <= mean - spread
    }
}

nonisolated struct AdjustedSession: Equatable, Sendable {
    let targetMinutes: Double
    let strengthSets: Int
    let extraRepsInReserve: Int
    let isRest: Bool
    let countsForProgression: Bool
    let note: String?
}

nonisolated enum SessionAdjuster {
    static let easyRestMinutes = 20.0
    static let yellowLongShare = 0.75
    static let lowWeekShare = 0.55

    static func adjust(kind: SessionKind, targetMinutes: Double, strengthSets: Int, color: DayColor,
                       weekBadDays: Int) -> AdjustedSession {
        let isStrength = kind == .strength
        switch color {
        case .red:
            return AdjustedSession(targetMinutes: isStrength ? 0 : easyRestMinutes, strengthSets: 0,
                                   extraRepsInReserve: 0, isRest: true, countsForProgression: false,
                                   note: isStrength ? "Skip strength today." : "Rest, or at most 20 very easy minutes.")
        case .yellow:
            if isStrength {
                return AdjustedSession(targetMinutes: targetMinutes, strengthSets: max(strengthSets - 1, 1),
                                       extraRepsInReserve: 1, isRest: false, countsForProgression: false,
                                       note: strengthSets > 1
                                           ? "One set less and one more rep in reserve. Today does not count for progression."
                                           : "One more rep in reserve. Today does not count for progression.")
            }
            let minutes = kind == .long ? rounded(targetMinutes * yellowLongShare) : targetMinutes
            return AdjustedSession(targetMinutes: minutes, strengthSets: 0, extraRepsInReserve: 0, isRest: false,
                                   countsForProgression: true,
                                   note: kind == .long ? "Shortened by a quarter. Keep the effort at 4 or less."
                                                       : "Keep the effort at 4 or less.")
        case .green, .unknown:
            guard weekBadDays >= TrainingPlanner.badDaysForRepeat else {
                return AdjustedSession(targetMinutes: targetMinutes, strengthSets: strengthSets, extraRepsInReserve: 0,
                                       isRest: false, countsForProgression: true, note: nil)
            }
            return AdjustedSession(targetMinutes: isStrength ? targetMinutes : rounded(targetMinutes * lowWeekShare),
                                   strengthSets: isStrength ? max(strengthSets - 1, 1) : 0, extraRepsInReserve: 0,
                                   isRest: false, countsForProgression: !isStrength,
                                   note: "Three low days this week: the rest of the week is lighter.")
        }
    }

    private static func rounded(_ minutes: Double) -> Double {
        max(10, (minutes / 5).rounded() * 5)
    }
}

nonisolated enum ScreeningGate {
    nonisolated enum Status: Equatable, Sendable {
        case blocked
        case walkingOnly
        case full
    }

    static let walkingOnlyBMI = 35.0

    static let questions = [
        "Has a doctor ever told you that you have a heart condition or high blood pressure?",
        "Do you get pain or pressure in your chest at rest, in daily life, or when you exercise?",
        "Have you lost your balance from dizziness or fainted in the last 12 months?",
        "Do you have a long-term condition other than heart disease or high blood pressure, such as diabetes?",
        "Do you take prescribed medication for a long-term condition?",
        "Do you have a bone, joint or soft-tissue problem that gets worse when you are more active?",
        "Has a doctor told you to exercise only under medical supervision?"
    ]

    static func status(hasFlag: Bool, doctorCleared: Bool, bmi: Double) -> Status {
        if doctorCleared { return .full }
        if hasFlag { return .blocked }
        return bmi >= walkingOnlyBMI ? .walkingOnly : .full
    }
}
