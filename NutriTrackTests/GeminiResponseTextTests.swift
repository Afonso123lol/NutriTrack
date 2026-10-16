import XCTest
@testable import NutriTrack

final class GeminiResponseTextTests: XCTestCase {

    func testSkipsThoughtParts() {
        let parts: [[String: Any]] = [
            ["text": "Goal: give tips. Constraint: two tips.", "thought": true],
            ["text": "1. Carry a bottle. 2. Drink after waking."]
        ]
        XCTAssertEqual(GeminiService.answerText(fromParts: parts), "1. Carry a bottle. 2. Drink after waking.")
    }

    func testJoinsMultipleAnswerParts() {
        let parts: [[String: Any]] = [
            ["text": "planning", "thought": true],
            ["text": "{\"a\":"],
            ["text": "1}"]
        ]
        XCTAssertEqual(GeminiService.answerText(fromParts: parts), "{\"a\":1}")
    }

    func testPartsWithoutThoughtFlagAreKept() {
        let parts: [[String: Any]] = [["text": "plain answer"]]
        XCTAssertEqual(GeminiService.answerText(fromParts: parts), "plain answer")
    }

    func testOnlyThoughtsYieldsEmpty() {
        let parts: [[String: Any]] = [["text": "thinking", "thought": true]]
        XCTAssertEqual(GeminiService.answerText(fromParts: parts), "")
    }
}
