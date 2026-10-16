import XCTest
@testable import NutriTrack

final class GreetingTests: XCTestCase {

    private func date(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 3
        components.hour = hour
        components.minute = 0
        return Calendar.current.date(from: components)!
    }

    func testMorningWithName() {
        XCTAssertEqual(Greeting.text(for: date(hour: 8), name: "Afonso"), "Good morning, Afonso")
    }

    func testMorningStartsAtFive() {
        XCTAssertEqual(Greeting.text(for: date(hour: 5), name: nil), "Good morning")
        XCTAssertEqual(Greeting.text(for: date(hour: 4), name: nil), "Good evening")
    }

    func testAfternoonStartsAtNoon() {
        XCTAssertEqual(Greeting.text(for: date(hour: 11), name: nil), "Good morning")
        XCTAssertEqual(Greeting.text(for: date(hour: 12), name: nil), "Good afternoon")
    }

    func testEveningStartsAtSix() {
        XCTAssertEqual(Greeting.text(for: date(hour: 17), name: nil), "Good afternoon")
        XCTAssertEqual(Greeting.text(for: date(hour: 18), name: nil), "Good evening")
        XCTAssertEqual(Greeting.text(for: date(hour: 23), name: nil), "Good evening")
    }

    func testBlankNameIsOmitted() {
        XCTAssertEqual(Greeting.text(for: date(hour: 9), name: ""), "Good morning")
        XCTAssertEqual(Greeting.text(for: date(hour: 9), name: "   "), "Good morning")
    }

    func testNameIsTrimmed() {
        XCTAssertEqual(Greeting.text(for: date(hour: 15), name: "  Afonso "), "Good afternoon, Afonso")
    }
}
