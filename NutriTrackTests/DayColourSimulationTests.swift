import XCTest
@testable import NutriTrack

final class DayColourSimulationTests: XCTestCase {

    private struct FixedSeedGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private struct Scenario {
        let name: String
        let energy: [Int]
        let sleep: ClosedRange<Double>
        let limit: Double
    }

    private func weeksWithThreeOrMoreYellowDays(_ scenario: Scenario, weeks: Int) -> Double {
        var generator = FixedSeedGenerator(seed: 20261013)
        var baseline: [Int] = []
        var bad = 0
        for _ in 0..<weeks {
            var yellow = 0
            for _ in 0..<7 {
                let energy = scenario.energy.randomElement(using: &generator) ?? 4
                let sleep = Double.random(in: scenario.sleep, using: &generator)
                let state = DayState(energy: energy, sleepHours: sleep, isSick: false, hasPain: false,
                                     energyBaseline: baseline)
                if DayReadiness.color(state) == .yellow { yellow += 1 }
                baseline.append(energy)
                if baseline.count > 28 { baseline.removeFirst() }
            }
            if yellow >= 3 { bad += 1 }
        }
        return Double(bad) / Double(weeks)
    }

    private let steadyEnergy = [3, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 4, 4, 5, 4, 5, 4, 4, 5]
    private let irregularEnergy = [2, 3, 3, 4, 4, 4, 5, 5, 5, 4, 3, 4, 5, 4, 5, 3, 4, 5, 4, 4]

    func testASteadySleeperRarelyGetsThreeYellowDaysInAWeek() {
        let scenarios = [
            Scenario(name: "typical", energy: steadyEnergy, sleep: 6.1...8.9, limit: 0.10),
            Scenario(name: "steady", energy: steadyEnergy, sleep: 6.0...8.6, limit: 0.10),
            Scenario(name: "very steady", energy: [4, 4, 4, 4, 5, 5, 5, 5, 4, 4, 5, 5, 4, 5, 4, 5, 4, 4, 5, 4],
                     sleep: 7.0...9.0, limit: 0.01)
        ]
        for scenario in scenarios {
            let share = weeksWithThreeOrMoreYellowDays(scenario, weeks: 4000)
            XCTAssertLessThan(share, scenario.limit, scenario.name)
        }
    }

    func testAnIrregularSleeperGetsThemOftenAndTheShortNightsAreWhy() {
        let withShortNights = Scenario(name: "irregular", energy: irregularEnergy, sleep: 5.4...9.4, limit: 0.40)
        let withoutShortNights = Scenario(name: "irregular, no short nights", energy: irregularEnergy,
                                          sleep: 6.1...9.4, limit: 0.15)
        let withShare = weeksWithThreeOrMoreYellowDays(withShortNights, weeks: 4000)
        let withoutShare = weeksWithThreeOrMoreYellowDays(withoutShortNights, weeks: 4000)
        XCTAssertGreaterThan(withShare, 0.20, "irregular")
        XCTAssertLessThan(withShare, withShortNights.limit, "irregular")
        XCTAssertLessThan(withoutShare, withoutShortNights.limit, "irregular, no short nights")
    }
}
