import Foundation

nonisolated struct NutritionHeadline: Equatable, Sendable {
    let title: String
    let detail: String

    static func make(eaten: Double, target: Double, showsRemaining: Bool) -> NutritionHeadline {
        let eatenKcal = Int(max(eaten, 0).rounded())
        let targetKcal = Int(max(target, 0).rounded())
        let difference = targetKcal - eatenKcal
        let gap = difference >= 0 ? "\(grouped(difference)) kcal left" : "\(grouped(-difference)) kcal over"
        if showsRemaining {
            return NutritionHeadline(title: gap + ".",
                                     detail: "\(grouped(eatenKcal)) eaten · \(grouped(targetKcal)) target")
        }
        let title = eatenKcal == 0 ? "Nothing eaten yet." : "\(grouped(eatenKcal)) kcal eaten."
        return NutritionHeadline(title: title, detail: "\(gap) · \(grouped(targetKcal)) target")
    }

    static func grouped(_ value: Int) -> String {
        let digits = Array(String(abs(value)))
        var result = ""
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 { result.append("\u{202F}") }
            result.append(digit)
        }
        return value < 0 ? "-" + result : result
    }
}
