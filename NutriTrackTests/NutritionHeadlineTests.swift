import XCTest
@testable import NutriTrack

final class NutritionHeadlineTests: XCTestCase {

    private let gap = "\u{202F}"

    func testGroupsThousandsWithANarrowSpace() {
        XCTAssertEqual(NutritionHeadline.grouped(999), "999")
        XCTAssertEqual(NutritionHeadline.grouped(1050), "1\(gap)050")
        XCTAssertEqual(NutritionHeadline.grouped(12345), "12\(gap)345")
        XCTAssertEqual(NutritionHeadline.grouped(0), "0")
    }

    func testRemainingModeSaysWhatIsLeft() {
        let headline = NutritionHeadline.make(eaten: 1844, target: 2894, showsRemaining: true)
        XCTAssertEqual(headline.title, "1\(gap)050 kcal left.")
        XCTAssertEqual(headline.detail, "1\(gap)844 eaten · 2\(gap)894 target")
    }

    func testRemainingModeSaysWhenOver() {
        let headline = NutritionHeadline.make(eaten: 3014.4, target: 2894, showsRemaining: true)
        XCTAssertEqual(headline.title, "120 kcal over.")
    }

    func testEatenModeSaysWhatWasEaten() {
        let headline = NutritionHeadline.make(eaten: 1844, target: 2894, showsRemaining: false)
        XCTAssertEqual(headline.title, "1\(gap)844 kcal eaten.")
        XCTAssertEqual(headline.detail, "1\(gap)050 kcal left · 2\(gap)894 target")
    }

    func testEatenModeWithoutMealsDoesNotShowAZero() {
        let headline = NutritionHeadline.make(eaten: 0, target: 2894, showsRemaining: false)
        XCTAssertEqual(headline.title, "Nothing eaten yet.")
    }

    func testBeforeTheFirstMealTheWholeTargetIsLeft() {
        let headline = NutritionHeadline.make(eaten: 0, target: 2894, showsRemaining: true)
        XCTAssertEqual(headline.title, "2\(gap)894 kcal left.")
    }
}
