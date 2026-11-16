import XCTest
import UIKit
@testable import NutriTrack

final class ModelJobTests: XCTestCase {

    func testJobRoundTripsForEveryKind() throws {
        let day = Calendar.current.startOfDay(for: Date())
        let kinds: [ModelJobKind] = [.mealAnalysis(pendingItemID: UUID()), .dailyCoach(day: day), .scoreEvaluation(day: day)]
        for kind in kinds {
            let job = ModelJob(kind: kind, attempt: 1)
            let decoded = try JSONDecoder().decode(ModelJob.self, from: JSONEncoder().encode(job))
            XCTAssertEqual(decoded, job)
        }
    }

    func testRetriesServerErrorsAndRateLimitWithinLimit() {
        for status in [429, 500, 502, 503, 504] {
            XCTAssertTrue(ModelRetryPolicy.shouldRetry(statusCode: status, errorCode: nil, attempt: 0), "\(status)")
        }
        XCTAssertTrue(ModelRetryPolicy.shouldRetry(statusCode: 503, errorCode: nil, attempt: 19))
        XCTAssertFalse(ModelRetryPolicy.shouldRetry(statusCode: 503, errorCode: nil, attempt: 20))
        XCTAssertEqual(ModelRetryPolicy.maxRetries, 20)
    }

    func testWaitsGrowAndThenStayAtFifteenMinutes() {
        XCTAssertEqual((0...6).map(ModelRetryPolicy.delay(beforeAttempt:)), [0, 5, 15, 60, 300, 900, 900])
        XCTAssertEqual(ModelRetryPolicy.delay(beforeAttempt: 20), 900)
        let total = (1...ModelRetryPolicy.maxRetries).reduce(0) { $0 + ModelRetryPolicy.delay(beforeAttempt: $1) }
        XCTAssertGreaterThan(total, 4 * 3600)
    }

    func testUnreadableAnswersAreRetriedWithinLimit() {
        XCTAssertTrue(ModelRetryPolicy.shouldRetryUnreadableAnswer(attempt: 0))
        XCTAssertFalse(ModelRetryPolicy.shouldRetryUnreadableAnswer(attempt: ModelRetryPolicy.maxRetries))
    }

    func testDoesNotRetryClientErrors() {
        for status in [400, 401, 403, 404] {
            XCTAssertFalse(ModelRetryPolicy.shouldRetry(statusCode: status, errorCode: nil, attempt: 0), "\(status)")
        }
        XCTAssertFalse(ModelRetryPolicy.shouldRetry(statusCode: nil, errorCode: nil, attempt: 0))
    }

    func testRetriesTransientNetworkErrors() {
        XCTAssertTrue(ModelRetryPolicy.shouldRetry(statusCode: nil, errorCode: .timedOut, attempt: 0))
        XCTAssertTrue(ModelRetryPolicy.shouldRetry(statusCode: nil, errorCode: .networkConnectionLost, attempt: 0))
        XCTAssertFalse(ModelRetryPolicy.shouldRetry(statusCode: nil, errorCode: .cancelled, attempt: 0))
        XCTAssertTrue(ModelRetryPolicy.shouldRetry(statusCode: nil, errorCode: .timedOut, attempt: 19))
        XCTAssertFalse(ModelRetryPolicy.shouldRetry(statusCode: nil, errorCode: .timedOut, attempt: 20))
    }

    func testNotifiesOnlyWhenAppIsNotActive() {
        XCTAssertFalse(ModelNotification.shouldNotify(applicationState: .active))
        XCTAssertTrue(ModelNotification.shouldNotify(applicationState: .inactive))
        XCTAssertTrue(ModelNotification.shouldNotify(applicationState: .background))
    }

    func testEventDetailsNameTheKindAndAttempt() {
        let id = UUID()
        let job = ModelJob(kind: .dailyCoach(day: Date()), id: id, attempt: 2)
        XCTAssertEqual(job.eventDetails, ["jobID": id.uuidString, "kind": "dailyCoach", "attempt": "2",
                                          "model": "gemma-4-31b-it"])
        XCTAssertEqual(ModelJob(kind: .dailyCoach(day: Date())).eventDetails["model"], "gemini-3.5-flash-lite")
        XCTAssertEqual(ModelJob(kind: .mealAnalysis(pendingItemID: UUID())).eventDetails["kind"], "mealAnalysis")
        XCTAssertEqual(ModelJob(kind: .scoreEvaluation(day: Date())).eventDetails["kind"], "scoreEvaluation")
    }

    func testNotificationContentDiffersBySuccess() {
        let kind = ModelJobKind.mealAnalysis(pendingItemID: UUID())
        XCTAssertEqual(ModelNotification.content(for: kind, succeeded: true).title, "Meal analysed")
        XCTAssertEqual(ModelNotification.content(for: kind, succeeded: false).title, "Meal analysis failed")
    }

    func testOldScoreJobsStillDecodeAndAreObsolete() throws {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        for kind in [ModelJobKind.scoreEvaluation(day: day), .dietEvaluation(day: day)] {
            let job = ModelJob(kind: kind)
            XCTAssertEqual(try JSONDecoder().decode(ModelJob.self, from: JSONEncoder().encode(job)), job)
            XCTAssertTrue(kind.isObsolete)
        }
        XCTAssertFalse(ModelJobKind.dailyCoach(day: day).isObsolete)
        XCTAssertFalse(ModelJobKind.mealAnalysis(pendingItemID: UUID()).isObsolete)
    }
}
