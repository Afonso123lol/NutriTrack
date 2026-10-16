import XCTest
@testable import NutriTrack

final class MultilineFieldTests: XCTestCase {

    func testTypingWithoutAReturnKeepsTheText() {
        let result = MultilineField.handleReturn(in: "two eggs")
        XCTAssertEqual(result.text, "two eggs")
        XCTAssertFalse(result.shouldClose)
    }

    func testAReturnAtTheEndClosesTheKeyboardAndIsRemoved() {
        let result = MultilineField.handleReturn(in: "two eggs\n")
        XCTAssertEqual(result.text, "two eggs")
        XCTAssertTrue(result.shouldClose)
    }

    func testAReturnInTheMiddleAlsoCloses() {
        let result = MultilineField.handleReturn(in: "two eggs\nand toast")
        XCTAssertEqual(result.text, "two eggs and toast")
        XCTAssertTrue(result.shouldClose)
    }

    func testSeveralReturnsCollapseIntoSingleSpaces() {
        let result = MultilineField.handleReturn(in: "a\n\nb\n")
        XCTAssertEqual(result.text, "a b")
        XCTAssertTrue(result.shouldClose)
    }

    func testTextThatIsOnlyReturnsEndsUpEmpty() {
        let result = MultilineField.handleReturn(in: "\n\n")
        XCTAssertEqual(result.text, "")
        XCTAssertTrue(result.shouldClose)
    }
}
