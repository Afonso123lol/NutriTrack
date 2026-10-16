import Foundation

nonisolated enum SuggestionChoice: String, Sendable {
    case applied
    case kept
}

nonisolated struct DaySessionPlan: Equatable, Sendable {
    let applied: AdjustedSession
    let suggestion: AdjustedSession?

    func suggestionText(kind: SessionKind, plannedMinutes: Double, plannedSets: Int) -> String? {
        guard let suggestion else { return nil }
        guard kind == .strength else {
            return "Suggested: \(Int(suggestion.targetMinutes)) min instead of \(Int(plannedMinutes))."
        }
        guard suggestion.strengthSets < plannedSets else { return "Suggested: one more rep in reserve on every set." }
        return "Suggested: \(suggestion.strengthSets) sets instead of \(plannedSets), with one more rep in reserve."
    }

    static func make(kind: SessionKind, targetMinutes: Double, strengthSets: Int, color: DayColor,
                     weekBadDays: Int, mode: YellowMode, choice: SuggestionChoice?) -> DaySessionPlan {
        let plain = SessionAdjuster.adjust(kind: kind, targetMinutes: targetMinutes, strengthSets: strengthSets,
                                           color: .green, weekBadDays: weekBadDays)
        let forColor = SessionAdjuster.adjust(kind: kind, targetMinutes: targetMinutes, strengthSets: strengthSets,
                                              color: color, weekBadDays: weekBadDays)
        guard color == .yellow else { return DaySessionPlan(applied: forColor, suggestion: nil) }
        let adjusted = AdjustedSession(targetMinutes: min(forColor.targetMinutes, plain.targetMinutes),
                                       strengthSets: min(forColor.strengthSets, plain.strengthSets),
                                       extraRepsInReserve: max(forColor.extraRepsInReserve, plain.extraRepsInReserve),
                                       isRest: false,
                                       countsForProgression: forColor.countsForProgression && plain.countsForProgression,
                                       note: forColor.note)
        let changesSomething = adjusted.targetMinutes != plain.targetMinutes
            || (kind == .strength && adjusted.strengthSets != plain.strengthSets)
            || adjusted.extraRepsInReserve != plain.extraRepsInReserve
        guard changesSomething else { return DaySessionPlan(applied: adjusted, suggestion: nil) }
        switch (mode, choice) {
        case (.off, _): return DaySessionPlan(applied: plain, suggestion: nil)
        case (.auto, _), (_, .applied?): return DaySessionPlan(applied: adjusted, suggestion: nil)
        case (_, .kept?): return DaySessionPlan(applied: plain, suggestion: nil)
        case (.suggest, nil): return DaySessionPlan(applied: plain, suggestion: adjusted)
        }
    }
}
