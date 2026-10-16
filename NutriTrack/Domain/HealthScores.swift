import Foundation

nonisolated struct ScoreComponent: Hashable, Sendable {
    let label: String
    let score: Double
    let weight: Double
}

nonisolated struct HealthScore: Hashable, Sendable {
    let value: Int
    let components: [ScoreComponent]
}

nonisolated enum HealthScores {
    static func sleepScore(hours: Double, quality: Int, bedtimes: [Date]) -> HealthScore {
        let duration = clamp(1 - min(abs(hours - 8) / 4, 1))
        let qualityScore = clamp((Double(quality) - 1) / 4)

        if bedtimes.count < 3 {
            let durationWeight = 0.5 / 0.8
            let qualityWeight = 0.3 / 0.8
            let components = [
                ScoreComponent(label: "Duration", score: duration, weight: durationWeight),
                ScoreComponent(label: "Quality", score: qualityScore, weight: qualityWeight)
            ]
            return makeScore(components)
        }

        let minutes = bedtimes.map(minutesSinceNoon)
        let mean = minutes.reduce(0, +) / Double(minutes.count)
        let variance = minutes.reduce(0) { $0 + pow($1 - mean, 2) } / Double(minutes.count)
        let stddev = sqrt(variance)
        let consistency = clamp(max(0, 1 - stddev / 120))

        let components = [
            ScoreComponent(label: "Duration", score: duration, weight: 0.5),
            ScoreComponent(label: "Quality", score: qualityScore, weight: 0.3),
            ScoreComponent(label: "Consistency", score: consistency, weight: 0.2)
        ]
        return makeScore(components)
    }

    static func readinessScore(todayEnergy: Int, lastNightSleep: HealthScore, last7SleepHours: [Double]) -> HealthScore {
        let sleepLastNight = clamp(Double(lastNightSleep.value) / 100)
        let energy = clamp((Double(todayEnergy) - 1) / 4)

        if last7SleepHours.isEmpty {
            let sleepWeight = 0.4 / 0.8
            let energyWeight = 0.4 / 0.8
            let components = [
                ScoreComponent(label: "Sleep last night", score: sleepLastNight, weight: sleepWeight),
                ScoreComponent(label: "Energy", score: energy, weight: energyWeight)
            ]
            return makeScore(components)
        }

        let mean = last7SleepHours.reduce(0, +) / Double(last7SleepHours.count)
        let weeklySleep = clamp(min(mean / 8, 1))

        let components = [
            ScoreComponent(label: "Sleep last night", score: sleepLastNight, weight: 0.4),
            ScoreComponent(label: "Energy", score: energy, weight: 0.4),
            ScoreComponent(label: "7-day sleep average", score: weeklySleep, weight: 0.2)
        ]
        return makeScore(components)
    }

    static func dietScore(
        calories: Double,
        proteinG: Double,
        fiberG: Double,
        saturatedFatG: Double,
        sodiumMg: Double,
        microRatios: [Double],
        targets: MacroTargets,
        limits: NutrientLimits,
        isClosed: Bool
    ) -> HealthScore {
        let target = targets.calories
        let eaten = isClosed ? 1.0 : min(max(calories / target, 0.1), 1.0)

        let deviation = isClosed ? abs(calories - target) : max(calories - target, 0)
        let caloriesScore = clamp(1 - min(deviation / (target * 0.25), 1))

        let proteinScore = clamp(min(proteinG / (targets.proteinG * eaten), 1))

        let fiberScore = clamp(min(fiberG / (limits.fiberMinG * eaten), 1))
        let microsScore = microRatios.isEmpty ? 0
            : microRatios.reduce(0) { $0 + clamp(min($1 / eaten, 1)) } / Double(microRatios.count)
        let fiberMicrosScore = clamp((fiberScore + microsScore) / 2)

        let excessesScore = (excessScore(saturatedFatG, limit: target * 0.10 / 9)
            + excessScore(sodiumMg, limit: limits.sodiumMaxMg)) / 2

        let components = [
            ScoreComponent(label: "Calories", score: caloriesScore, weight: 0.3),
            ScoreComponent(label: "Protein", score: proteinScore, weight: 0.3),
            ScoreComponent(label: "Fiber + micros", score: fiberMicrosScore, weight: 0.2),
            ScoreComponent(label: "Excesses", score: excessesScore, weight: 0.2)
        ]
        return makeScore(components)
    }

    private static func excessScore(_ value: Double, limit: Double) -> Double {
        guard value > limit else { return 1 }
        return clamp(1 - (value - limit) / (limit * 0.5))
    }

    private static func minutesSinceNoon(_ date: Date) -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        var minutes = Double(hour * 60 + minute)
        if hour < 12 { minutes += 1440 }
        return minutes
    }

    private static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    private static func makeScore(_ components: [ScoreComponent]) -> HealthScore {
        let total = components.reduce(0) { $0 + $1.score * $1.weight }
        return HealthScore(value: Int((total * 100).rounded()), components: components)
    }
}
