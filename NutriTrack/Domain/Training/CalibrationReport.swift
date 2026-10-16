import Foundation

nonisolated struct CalibrationReport: Equatable, Sendable {
    nonisolated struct Day: Equatable, Sendable {
        let color: DayColor
        let rpe: Int?
        let doneMinutes: Double?
        let plannedMinutes: Double?
        let dayEnergy: Int?
        var choice: SuggestionChoice?
    }

    nonisolated struct Side: Equatable, Sendable {
        let days: Int
        let sessions: Int
        let medianRPE: Double?
        let medianDoneShare: Double?
        let medianDayEnergy: Double?
    }

    static let minimumDays = 10

    let yellowSide: Side
    let greenSide: Side
    let acceptedSide: Side

    var hasEnough: Bool { yellowSide.days >= Self.minimumDays && greenSide.days >= Self.minimumDays }

    var verdict: String? {
        let measured = [(yellowSide.medianRPE, greenSide.medianRPE),
                        (yellowSide.medianDoneShare, greenSide.medianDoneShare),
                        (yellowSide.medianDayEnergy, greenSide.medianDayEnergy)]
            .contains { $0.0 != nil && $0.1 != nil }
        guard hasEnough, measured else { return nil }
        let harderEffort = difference(yellowSide.medianRPE, greenSide.medianRPE) >= 1
        let lessDone = difference(greenSide.medianDoneShare, yellowSide.medianDoneShare) >= 0.1
        let lowerEnergy = difference(greenSide.medianDayEnergy, yellowSide.medianDayEnergy) >= 0.5
        return harderEffort || lessDone || lowerEnergy
            ? "Your yellow days do look harder than your green ones."
            : "Your yellow days look like your green ones. The rule may not be for you."
    }

    static func make(_ days: [Day]) -> CalibrationReport {
        CalibrationReport(yellowSide: side(days.filter { $0.color == .yellow && $0.choice != .applied }),
                          greenSide: side(days.filter { $0.color == .green }),
                          acceptedSide: side(days.filter { $0.color == .yellow && $0.choice == .applied }))
    }

    private static func side(_ days: [Day]) -> Side {
        let shares = days.compactMap { day -> Double? in
            guard let done = day.doneMinutes, let planned = day.plannedMinutes, planned > 0 else { return nil }
            return done / planned
        }
        return Side(days: days.count,
                    sessions: days.filter { $0.doneMinutes != nil }.count,
                    medianRPE: median(days.compactMap(\.rpe).map(Double.init)),
                    medianDoneShare: median(shares),
                    medianDayEnergy: median(days.compactMap(\.dayEnergy).map(Double.init)))
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private func difference(_ left: Double?, _ right: Double?) -> Double {
        guard let left, let right else { return 0 }
        return left - right
    }
}
