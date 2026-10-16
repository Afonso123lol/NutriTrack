import XCTest
@testable import NutriTrack

final class NutrientReadingTests: XCTestCase {

    private func reading(_ rule: NutrientReading.Rule, value: Double, floor: Double = 0, ceiling: Double = 0,
                         showsStatus: Bool = true) -> NutrientReading {
        NutrientReading(name: "X", value: value, unit: "mg", floor: floor, ceiling: ceiling, rule: rule,
                        showsStatus: showsStatus)
    }

    func testRangeWords() {
        XCTAssertEqual(reading(.range, value: 4, floor: 8, ceiling: 45).word, "Low")
        XCTAssertEqual(reading(.range, value: 12, floor: 8, ceiling: 45).word, "On target")
        XCTAssertEqual(reading(.range, value: 50, floor: 8, ceiling: 45).word, "Over limit")
    }

    func testLimitWords() {
        XCTAssertEqual(reading(.limit, value: 10, ceiling: 72).word, "Within limit")
        XCTAssertEqual(reading(.limit, value: 60, ceiling: 72).word, "Near limit")
        XCTAssertEqual(reading(.limit, value: 80, ceiling: 72).word, "Over limit")
    }

    func testFloorIsLowOrOnTargetAndNeverOver() {
        XCTAssertEqual(reading(.floor, value: 2, floor: 4).word, "Low")
        XCTAssertEqual(reading(.floor, value: 4, floor: 4).word, "On target")
        XCTAssertEqual(reading(.floor, value: 4000, floor: 4).word, "On target")
        XCTAssertFalse(reading(.floor, value: 4000, floor: 4).geometry.isOver)
        XCTAssertEqual(reading(.floor, value: 2.5, floor: 4).amount, "2.5 / 4+ mg")
    }

    func testPlainHasNoWordAndShowsOnlyTheAmount() {
        let sugar = reading(.plain, value: 80)
        XCTAssertEqual(sugar.word, "")
        XCTAssertEqual(sugar.status, .good)
        XCTAssertEqual(sugar.amount, "80 mg")
    }

    func testWithoutStatusThereIsNoWordAndTheBarIsNeverRed() {
        let over = reading(.range, value: 50, floor: 8, ceiling: 45, showsStatus: false)
        XCTAssertEqual(over.word, "")
        XCTAssertFalse(over.geometry.isOver)
        XCTAssertEqual(over.geometry.fill, reading(.range, value: 50, floor: 8, ceiling: 45).geometry.fill, accuracy: 0.0001)
    }

    func testOverWordCanSayItIsASafeLevel() {
        var iron = reading(.range, value: 41, floor: 11, ceiling: 40)
        iron.overWord = "Above safe level"
        XCTAssertEqual(iron.word, "Above safe level")
    }

    func testSupplementNote() {
        XCTAssertEqual(reading(.supplementLimit(taken: 300), value: 600, floor: 350, ceiling: 250).supplementNote,
                       "From supplements: 300 of 250 mg limit")
        var iron = reading(.range, value: 20, floor: 11, ceiling: 40)
        XCTAssertNil(iron.supplementNote)
        iron.fromSupplements = 14
        XCTAssertEqual(iron.supplementNote, "From supplements: 14 mg")
    }

    func testAmountKeepsADecimalForSmallNumbers() {
        XCTAssertEqual(reading(.range, value: 0.64, floor: 1.2, ceiling: 50).amount, "0.6 / 1.2–50 mg")
        XCTAssertEqual(reading(.range, value: 412.4, floor: 400, ceiling: 2500).amount, "412 / 400–2500 mg")
        XCTAssertEqual(reading(.limit, value: 12, ceiling: 72.38).amount, "12 / max 72.4 mg")
        XCTAssertEqual(reading(.supplementLimit(taken: 0), value: 380, floor: 400, ceiling: 350).amount, "380 / 400+ mg")
    }

    func testRangeGeometryPutsTheFloorAtSixtyPercent() {
        XCTAssertEqual(reading(.range, value: 8, floor: 8, ceiling: 45).geometry.fill, 0.6, accuracy: 0.0001)
    }
}
