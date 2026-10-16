import Foundation

nonisolated enum TrainingPhase: String, Sendable {
    case transition
    case base
}

nonisolated enum SessionKind: String, Sendable {
    case easy
    case long
    case strength
}

nonisolated enum Modality: String, CaseIterable, Sendable {
    case walk
    case incline
    case hike
    case stairs
    case bike
    case other
    case strength

    static let aerobic: [Modality] = [.walk, .incline, .hike, .stairs, .bike, .other]

    var label: String {
        switch self {
        case .walk: return "Walk"
        case .incline: return "Incline treadmill"
        case .hike: return "Hike"
        case .stairs: return "Stairs"
        case .bike: return "Bike"
        case .other: return "Other"
        case .strength: return "Strength"
        }
    }

    var icon: String {
        switch self {
        case .walk, .incline: return "figure.walk"
        case .hike: return "figure.hiking"
        case .stairs: return "figure.stairs"
        case .bike: return "figure.outdoor.cycle"
        case .other: return "figure.mixed.cardio"
        case .strength: return "dumbbell.fill"
        }
    }
}

nonisolated enum WeekDecision: String, Sendable {
    case start
    case restart
    case returnAfterOneWeek
    case returnAfterTwoWeeks
    case progress
    case repeatWeek
    case reduce
    case lowReadiness
    case deload
    case afterDeload
}

nonisolated struct WeekSummary: Equatable, Sendable {
    let plannedMinutes: Double
    let doneMinutes: Double
    let isDeload: Bool
    let badDays: Int
    let blockIndex: Int
    let weekInBlock: Int
}

nonisolated struct PlannerInput: Sendable {
    let daysPerWeek: Int
    let declaredWeeklyMinutes: Double
    let bmi: Double
    let hasTreadmill: Bool
    let hasBike: Bool
    let allowsStrength: Bool
    let history: [WeekSummary]
    let weeksSinceStart: Int
    let daysSinceLastSession: Int?
    let recentDoneMinutes: [Double]
    let longestSessionLast30Days: Double
}

nonisolated struct SessionPlan: Equatable, Sendable {
    let dayIndex: Int
    let kind: SessionKind
    let modality: Modality
    let targetMinutes: Double
    let strengthSets: Int
}

nonisolated struct WeekPlan: Equatable, Sendable {
    let phase: TrainingPhase
    let blockIndex: Int
    let weekInBlock: Int
    let isDeload: Bool
    let targetMinutes: Double
    let basisMinutes: Double
    let decision: WeekDecision
    let strengthSets: Int
    let suggestsFewerDays: Bool
    let sessions: [SessionPlan]
}

nonisolated enum TrainingPlanner {
    static let minimumWeeklyMinutes = 75.0
    static let maximumStartMinutes = 480.0
    static let smallVolumeThreshold = 150.0
    static let minutesPerSessionStep = 5.0
    static let weeklyIncrease = 0.05
    static let deloadShare = 0.55
    static let longShare = 0.275
    static let sessionPeakFactor = 1.10
    static let transitionWeeks = 8
    static let progressAdherence = 0.85
    static let repeatAdherence = 0.70
    static let badDaysForRepeat = 3

    static func trainingDays(_ daysPerWeek: Int) -> [Int] {
        switch min(max(daysPerWeek, 3), 6) {
        case 3: return [0, 2, 5]
        case 4: return [0, 1, 3, 5]
        case 5: return [0, 1, 3, 4, 5]
        default: return [0, 1, 2, 3, 4, 5]
        }
    }

    static func strengthDays(_ daysPerWeek: Int) -> [Int] {
        min(max(daysPerWeek, 3), 6) == 3 ? [0, 2] : [0, 3]
    }

    static func strengthSets(weekNumber: Int, isDeload: Bool) -> Int {
        let sets = weekNumber <= 2 ? 1 : (weekNumber <= 6 ? 2 : 3)
        return isDeload ? max(sets - 1, 1) : sets
    }

    static func phase(weekNumber: Int) -> TrainingPhase {
        weekNumber <= transitionWeeks ? .transition : .base
    }

    static func cycleLength(phase: TrainingPhase, bmi: Double) -> Int {
        phase == .transition || bmi >= 30 ? 3 : 4
    }

    static func nextWeek(_ input: PlannerInput) -> WeekPlan {
        let history = input.history
        var decision = WeekDecision.start
        var target = minimumWeeklyMinutes
        var basis = 0.0
        var blockIndex = history.last?.blockIndex ?? 0
        var weekInBlock = (history.last?.weekInBlock ?? 0) + 1
        var weekNumber = input.weeksSinceStart + 1
        var isDeload = false
        var suggestsFewerDays = false

        let lastFull = history.last { !$0.isDeload && $0.plannedMinutes > 0 && $0.doneMinutes / $0.plannedMinutes >= repeatAdherence }
        let reference = lastFull?.plannedMinutes ?? history.last?.plannedMinutes ?? minimumWeeklyMinutes

        if let last = history.last {
            if let gap = input.daysSinceLastSession, gap > 28 {
                decision = .restart
                let recent = history.suffix(4).map(\.doneMinutes)
                target = recent.reduce(0, +) / Double(recent.count) * 0.5
                blockIndex += 1
                weekInBlock = 1
                weekNumber = 1
            } else if let gap = input.daysSinceLastSession, gap >= 15 {
                decision = .returnAfterTwoWeeks
                target = reference * 0.65
                blockIndex += 1
                weekInBlock = 1
            } else if let gap = input.daysSinceLastSession, gap >= 8 {
                decision = .returnAfterOneWeek
                target = reference * 0.80
                blockIndex += 1
                weekInBlock = 1
            } else if last.isDeload {
                decision = .afterDeload
                let block = history.filter { $0.blockIndex == last.blockIndex && !$0.isDeload }
                target = block.first { $0.weekInBlock == 2 }?.plannedMinutes ?? block.last?.plannedMinutes ?? reference
                blockIndex += 1
                weekInBlock = 1
            } else if weekInBlock >= cycleLength(phase: phase(weekNumber: weekNumber), bmi: input.bmi) {
                decision = .deload
                isDeload = true
                let block = history.filter { $0.blockIndex == last.blockIndex && !$0.isDeload }
                target = (block.map(\.plannedMinutes).max() ?? last.plannedMinutes) * deloadShare
            } else if last.badDays >= badDaysForRepeat {
                decision = .lowReadiness
                target = last.plannedMinutes
            } else {
                let adherence = last.plannedMinutes > 0 ? last.doneMinutes / last.plannedMinutes : 0
                let previous = history.dropLast().last
                let previousAdherence = previous.map { $0.plannedMinutes > 0 ? $0.doneMinutes / $0.plannedMinutes : 0 }
                if adherence >= progressAdherence {
                    decision = .progress
                    basis = min(last.doneMinutes, last.plannedMinutes)
                    target = basis < smallVolumeThreshold
                        ? basis + minutesPerSessionStep * Double(trainingDays(input.daysPerWeek).count)
                        : basis * (1 + weeklyIncrease)
                } else if adherence < repeatAdherence, let previous, let previousAdherence,
                          previousAdherence < repeatAdherence, !previous.isDeload {
                    decision = .reduce
                    target = (last.doneMinutes + previous.doneMinutes) / 2
                    suggestsFewerDays = true
                } else {
                    decision = .repeatWeek
                    target = last.plannedMinutes
                }
            }
        } else {
            let logged = input.recentDoneMinutes
            let loggedMean = logged.isEmpty ? 0 : logged.reduce(0, +) / Double(logged.count)
            target = min(loggedMean > 0 ? loggedMean : input.declaredWeeklyMinutes, maximumStartMinutes)
            blockIndex = 1
            weekInBlock = 1
            weekNumber = 1
        }
        if !isDeload { target = max(target, minimumWeeklyMinutes) }

        let phase = phase(weekNumber: weekNumber)
        let sets = input.allowsStrength ? strengthSets(weekNumber: weekNumber, isDeload: isDeload) : 0
        let sessions = sessions(targetMinutes: target, input: input, phase: phase, strengthSets: sets)
        let total = sessions.filter { $0.kind != .strength }.reduce(0) { $0 + $1.targetMinutes }
        return WeekPlan(phase: phase, blockIndex: blockIndex, weekInBlock: weekInBlock, isDeload: isDeload,
                        targetMinutes: total, basisMinutes: basis, decision: decision, strengthSets: sets,
                        suggestsFewerDays: suggestsFewerDays, sessions: sessions)
    }

    static func sessions(targetMinutes: Double, input: PlannerInput, phase: TrainingPhase,
                         strengthSets: Int) -> [SessionPlan] {
        let days = trainingDays(input.daysPerWeek)
        let hasLong = days.count >= 4
        let cap = input.longestSessionLast30Days > 0
            ? max(input.longestSessionLast30Days * sessionPeakFactor, 20) : Double.infinity
        var minutes = Array(repeating: targetMinutes / Double(days.count), count: days.count)
        if hasLong {
            let long = targetMinutes * longShare
            minutes = Array(repeating: (targetMinutes - long) / Double(days.count - 1), count: days.count - 1) + [long]
        }
        minutes = minutes.map { max(10, (min($0, cap) / 5).rounded() * 5) }

        var plans: [SessionPlan] = []
        var easyCount = 0
        for (index, day) in days.enumerated() {
            let isLong = hasLong && index == days.count - 1
            var modality = Modality.walk
            if isLong {
                modality = phase == .base ? .hike : .walk
            } else {
                easyCount += 1
                if easyCount == 2, input.hasTreadmill { modality = .incline }
                if easyCount == 3, input.hasBike, hasLong { modality = .bike }
            }
            plans.append(SessionPlan(dayIndex: day, kind: isLong ? .long : .easy, modality: modality,
                                     targetMinutes: minutes[index], strengthSets: 0))
        }
        if strengthSets > 0 {
            for day in strengthDays(input.daysPerWeek) {
                plans.append(SessionPlan(dayIndex: day, kind: .strength, modality: .strength,
                                         targetMinutes: Double(10 + 10 * strengthSets), strengthSets: strengthSets))
            }
        }
        return plans.sorted { ($0.dayIndex, $0.kind == .strength ? 1 : 0) < ($1.dayIndex, $1.kind == .strength ? 1 : 0) }
    }
}
