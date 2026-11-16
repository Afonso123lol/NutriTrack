import Foundation

nonisolated struct DayOverview: Equatable, Sendable {
    nonisolated struct Card: Equatable, Sendable {
        let title: String
        let value: String
        let detail: String
        var extra: String? = nil
        var spokenExtra: String? = nil

        var accessibility: String {
            let text = [title, value == "—" ? "not yet" : value, detail, spokenExtra ?? extra].compactMap { $0 }
                .joined(separator: ", ")
            return text
                .replacingOccurrences(of: #"(\d) h\b"#, with: "$1 hours", options: .regularExpression)
                .replacingOccurrences(of: " kcal", with: " kilocalories")
        }
    }

    let today: Card
    let sleep: Card
    let food: Card

    static func make(color: DayColor, hasCheckIn: Bool, sleepHours: Double?, sleepNeed: Double,
                     eatenKcal: Double, targetKcal: Double, proteinG: Double, targetProteinG: Double) -> DayOverview {
        let today: Card
        switch (hasCheckIn, color) {
        case (false, _), (_, .unknown): today = Card(title: "Today", value: "Check in", detail: "to read today")
        case (_, .green): today = Card(title: "Today", value: "Good to go", detail: "Train as planned")
        case (_, .yellow): today = Card(title: "Today", value: "Easy day", detail: "Lighter option")
        case (_, .red): today = Card(title: "Today", value: "Rest day", detail: "Training off")
        }
        let need = DayHeadline.hours(sleepNeed)
        let sleep = sleepHours.flatMap { $0 > 0 ? $0 : nil }
            .map { Card(title: "Sleep", value: "\(DayHeadline.hours($0)) h", detail: "of \(need) h need") }
            ?? Card(title: "Sleep", value: "—", detail: "need \(need) h")
        let kcal = Int(eatenKcal.rounded())
        let protein = Int(proteinG.rounded())
        let targetProtein = Int(targetProteinG.rounded())
        let food = Card(title: "Food", value: "\(kcal)", detail: "of \(Int(targetKcal.rounded())) kcal",
                        extra: "\(protein)/\(targetProtein) g protein",
                        spokenExtra: "\(protein) of \(targetProtein) g protein")
        return DayOverview(today: today, sleep: sleep, food: food)
    }
}
