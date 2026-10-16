import XCTest
@testable import NutriTrack

final class WeightValidatorTests: XCTestCase {

    func testParseAcceptsCommaAndSpaces() {
        XCTAssertEqual(WeightValidator.parse(" 78,4 "), 78.4)
        XCTAssertEqual(WeightValidator.parse("80"), 80)
        XCTAssertNil(WeightValidator.parse("abc"))
        XCTAssertNil(WeightValidator.parse(""))
    }

    func testOutOfRangeIsInvalid() {
        XCTAssertEqual(WeightValidator.check(29.9, last: nil), .invalid)
        XCTAssertEqual(WeightValidator.check(300.1, last: nil), .invalid)
        XCTAssertEqual(WeightValidator.check(.nan, last: 80), .invalid)
        XCTAssertEqual(WeightValidator.check(784, last: 78), .invalid)
    }

    func testBoundsAreValid() {
        XCTAssertEqual(WeightValidator.check(30, last: nil), .ok)
        XCTAssertEqual(WeightValidator.check(300, last: nil), .ok)
    }

    func testSmallChangeIsAccepted() {
        XCTAssertEqual(WeightValidator.check(81, last: 80), .ok)
        XCTAssertEqual(WeightValidator.check(84, last: 80), .ok)
    }

    func testJumpAboveFivePercentAsksForConfirmation() {
        guard case .needsConfirmation(let percent) = WeightValidator.check(88, last: 80) else {
            return XCTFail("expected confirmation")
        }
        XCTAssertEqual(percent, 10, accuracy: 0.0001)
        guard case .needsConfirmation = WeightValidator.check(72, last: 80) else {
            return XCTFail("expected confirmation")
        }
    }

    func testFirstWeighInNeedsNoConfirmation() {
        XCTAssertEqual(WeightValidator.check(95, last: nil), .ok)
    }

    func testConfirmationMessageNamesTheWeightAndTheChange() {
        XCTAssertEqual(WeightValidator.confirmationMessage(weightKg: 88, percent: 10),
                       "That's 88.0 kg, 10% from your last weigh-in. Save anyway?")
    }
}
