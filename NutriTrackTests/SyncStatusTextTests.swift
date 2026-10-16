import XCTest
@testable import NutriTrack

final class SyncStatusTextTests: XCTestCase {

    private let time: (Date) -> String = { _ in "10:32" }

    func testOffWhenNotConfigured() {
        XCTAssertEqual(SyncStatusText.describe(isConfigured: false, pendingCount: 3, lastSentAt: nil, lastError: nil, time: time), "Sync off")
    }

    func testPendingWithLastSent() {
        XCTAssertEqual(SyncStatusText.describe(isConfigured: true, pendingCount: 12, lastSentAt: Date(), lastError: nil, time: time),
                       "12 pending · last sent 10:32")
    }

    func testUpToDate() {
        XCTAssertEqual(SyncStatusText.describe(isConfigured: true, pendingCount: 0, lastSentAt: Date(), lastError: nil, time: time),
                       "Up to date · last sent 10:32")
    }

    func testNothingSentYet() {
        XCTAssertEqual(SyncStatusText.describe(isConfigured: true, pendingCount: 0, lastSentAt: nil, lastError: nil, time: time), "Nothing sent yet")
        XCTAssertEqual(SyncStatusText.describe(isConfigured: true, pendingCount: 4, lastSentAt: nil, lastError: nil, time: time), "4 pending")
    }

    func testErrorIsShownWithPendingCount() {
        XCTAssertEqual(SyncStatusText.describe(isConfigured: true, pendingCount: 4, lastSentAt: Date(), lastError: "The request timed out.", time: time),
                       "4 pending · The request timed out.")
    }
}
