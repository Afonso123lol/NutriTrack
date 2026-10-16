import Foundation

nonisolated enum SleepNeed {
    static let range = 7...10
    static let defaultHours = 8.0
    static let question = "How many hours of sleep do you need to feel rested?"

    static func resolved(_ stored: Double) -> Double {
        guard stored > 0 else { return defaultHours }
        return min(max(stored, Double(range.lowerBound)), Double(range.upperBound))
    }
}
