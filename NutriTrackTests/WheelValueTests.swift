import XCTest
@testable import NutriTrack

final class WheelValueTests: XCTestCase {
    func testSplitsIntoWholeAndTenth() {
        XCTAssertEqual(WheelValue.split(72.4, in: 30...200), WheelValue(whole: 72, tenth: 4))
        XCTAssertEqual(WheelValue.split(72.0, in: 30...200), WheelValue(whole: 72, tenth: 0))
    }

    func testRoundsToTheNearestTenthAndCarries() {
        XCTAssertEqual(WheelValue.split(79.96, in: 30...200), WheelValue(whole: 80, tenth: 0))
        XCTAssertEqual(WheelValue.split(72.38, in: 30...200), WheelValue(whole: 72, tenth: 4))
    }

    func testClampsToTheRange() {
        XCTAssertEqual(WheelValue.split(12, in: 30...200), WheelValue(whole: 30, tenth: 0))
        XCTAssertEqual(WheelValue.split(250.5, in: 30...200), WheelValue(whole: 200, tenth: 0))
    }

    func testCombineGivesBackTheValueAndStopsAtTheTop() {
        XCTAssertEqual(WheelValue.combine(whole: 72, tenth: 4, in: 30...200), 72.4, accuracy: 0.0001)
        XCTAssertEqual(WheelValue.combine(whole: 200, tenth: 7, in: 30...200), 200, accuracy: 0.0001)
        XCTAssertEqual(WheelValue.split(72.4, in: 30...200).value, 72.4, accuracy: 0.0001)
    }
}
