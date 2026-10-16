import Foundation

nonisolated struct DayIntake: Equatable, Sendable {
    let date: Date
    let calories: Double
}

nonisolated enum ExpenditureStatus: String, Equatable, Sendable {
    case updated
    case needsWeighIns
    case needsCompleteDays
    case tooNoisy
    case settling
}

nonisolated struct ExpenditureResult: Equatable, Sendable {
    let tdee: Double
    let status: ExpenditureStatus
    let completeDays: Int
}

nonisolated enum ExpenditureEstimator {
    static let energyPerKg = 7700.0
    static let defaultActivityFactor = 1.55
    static let windowDays = 28
    static let minimumCompleteDays = 20
    static let minimumCompleteDaysPerWeek = 4
    static let maximumSlopeErrorKcal = 250.0
    static let smoothing = 0.5
    static let maximumStep = 150.0
    static let lowerBoundFactor = 1.2
    static let upperBoundFactor = 2.4
    static let settlingDays = 14.0

    static func formula(restingRate: Double, activityFactor: Double) -> Double {
        restingRate * (activityFactor > 0 ? activityFactor : defaultActivityFactor)
    }

    static func update(previousTDEE: Double, restingRate: Double, rate: WeightRate,
                       completeDays: [DayIntake], now: Date) -> ExpenditureResult {
        let inWindow = completeDays.filter {
            let age = now.timeIntervalSince($0.date) / 86400
            return age >= 0 && age < Double(windowDays)
        }
        func keep(_ status: ExpenditureStatus) -> ExpenditureResult {
            ExpenditureResult(tdee: previousTDEE, status: status, completeDays: inWindow.count)
        }

        guard rate.isValid else { return keep(.needsWeighIns) }
        var perWeek = [0, 0, 0, 0]
        for day in inWindow {
            perWeek[min(Int(now.timeIntervalSince(day.date) / 86400 / 7), 3)] += 1
        }
        guard inWindow.count >= minimumCompleteDays,
              perWeek.allSatisfy({ $0 >= minimumCompleteDaysPerWeek }) else { return keep(.needsCompleteDays) }
        guard rate.standardError * energyPerKg <= maximumSlopeErrorKcal else { return keep(.tooNoisy) }

        let intake = inWindow.reduce(0) { $0 + $1.calories } / Double(inWindow.count)
        let observed = intake - energyPerKg * rate.slopeKgPerDay
        var next = previousTDEE + smoothing * (observed - previousTDEE)
        next = min(max(next, previousTDEE - maximumStep), previousTDEE + maximumStep)
        next = min(max(next, restingRate * lowerBoundFactor), restingRate * upperBoundFactor)
        return ExpenditureResult(tdee: next, status: .updated, completeDays: inWindow.count)
    }
}
