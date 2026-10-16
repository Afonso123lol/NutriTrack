import Foundation

nonisolated struct DayHeadline: Equatable, Sendable {
    let eyebrow: String
    let title: String
    let reason: String

    nonisolated struct Session: Equatable, Sendable {
        let name: String
        let isStrength: Bool
        let plannedMinutes: Double
        let adjustedMinutes: Double
        var isDone = false
        var hasSuggestion = false
        var isLighter = true
    }

    nonisolated struct Input: Sendable {
        var hasCheckIn = true
        var color = DayColor.green
        var sleepHours: Double? = nil
        var energy: Int? = nil
        var isSick = false
        var hasPain = false
        var reasons: [DayReason] = []
        var session: Session? = nil
    }

    static func make(_ input: Input) -> DayHeadline {
        guard input.hasCheckIn else {
            return DayHeadline(eyebrow: "Morning", title: "How did you sleep?",
                               reason: "Check in to get today's read.")
        }
        let reason = [facts(input), plan(input)].filter { !$0.isEmpty }.joined(separator: " ")
        switch input.color {
        case .green, .unknown:
            return DayHeadline(eyebrow: "Good to go",
                               title: input.session == nil ? "Rested and steady." : "Ready to move.",
                               reason: reason)
        case .yellow:
            return DayHeadline(eyebrow: "Easy day", title: "Take it easy today.", reason: reason)
        case .red:
            return DayHeadline(eyebrow: "Rest day",
                               title: input.isSick || input.hasPain ? "A day to recover." : "Go gently today.",
                               reason: reason)
        }
    }

    static func hours(_ value: Double) -> String {
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    private static func facts(_ input: Input) -> String {
        let cause = input.reasons.map(\.text).joined(separator: " ")
        guard cause.isEmpty else { return cause }
        if input.isSick { return DayReason.ill.text }
        if input.hasPain { return DayReason.pain.text }
        switch (input.sleepHours, input.energy) {
        case let (sleep?, energy?): return "You slept \(hours(sleep)) h and energy is \(energy) of 5."
        case let (sleep?, nil): return "You slept \(hours(sleep)) h."
        case let (nil, energy?): return "Energy is \(energy) of 5."
        case (nil, nil): return ""
        }
    }

    private static func plan(_ input: Input) -> String {
        if input.color == .red { return "Training is off today." }
        guard let session = input.session else { return "Nothing planned today." }
        let name = session.name.lowercased()
        if session.isDone { return "Today's \(name) is done." }
        switch input.color {
        case .green, .unknown:
            return session.isStrength ? "A good day for strength." : "A good day for the \(name)."
        case .yellow:
            if session.hasSuggestion { return "A lighter option is suggested below." }
            if session.isStrength { return session.isLighter ? "Strength is lighter today." : "Strength as planned." }
            return session.adjustedMinutes < session.plannedMinutes
                ? "The \(name) is shortened to \(Int(session.adjustedMinutes.rounded())) min."
                : "Keep the \(name) easy."
        case .red:
            return "Training is off today."
        }
    }
}
