import XCTest
@testable import NutriTrack

@MainActor
final class ModelJobRouterTests: XCTestCase {

    @MainActor
    private final class Recorder {
        var resent: [ModelJob] = []
        var meals: [(UUID, PendingMealStatus)] = []
        var coach: [(Date, String)] = []
        var notified: [(ModelJobKind, Bool)] = []
        var events: [(String, [String: String])] = []
    }

    private var day: Date { Calendar.current.startOfDay(for: Date()) }

    private func makeRouter() -> (ModelJobRouter, ModelJobStore, Recorder) {
        let store = ModelJobStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("router-\(UUID().uuidString)", isDirectory: true))
        let recorder = Recorder()
        let router = ModelJobRouter(
            store: store,
            resend: { recorder.resent.append($0) },
            applyMeal: { recorder.meals.append(($0, $1)) },
            applyCoach: { recorder.coach.append(($0, $1)) },
            notify: { recorder.notified.append(($0, $1)) },
            logEvent: { recorder.events.append(($0, $1)) }
        )
        return (router, store, recorder)
    }

    private func envelope(_ answer: String) -> Data {
        try! JSONSerialization.data(withJSONObject: ["candidates": [["content": ["parts": [
            ["text": "reasoning", "thought": true], ["text": answer]
        ]]]]])
    }

    func testCoachSuccessIsAppliedAndJobRemoved() throws {
        let (router, store, recorder) = makeRouter()
        let job = ModelJob(kind: .dailyCoach(day: day))
        try store.add(job, body: Data())
        router.handle(jobID: job.id, data: envelope("Eat more fibre."), statusCode: 200, error: nil)
        XCTAssertEqual(recorder.coach.first?.1, "Eat more fibre.")
        XCTAssertEqual(recorder.coach.first?.0, day)
        XCTAssertNil(store.job(id: job.id))
        XCTAssertEqual(recorder.notified.first?.1, true)
        XCTAssertEqual(recorder.events.map(\.0), ["model.completed"])
        XCTAssertNotNil(recorder.events.first?.1["durationS"])
    }

    func testObsoleteScoreJobIsDroppedWithoutApplyingOrNotifying() throws {
        let (router, store, recorder) = makeRouter()
        for kind in [ModelJobKind.scoreEvaluation(day: day), .dietEvaluation(day: day)] {
            let job = ModelJob(kind: kind)
            try store.add(job, body: Data())
            router.handle(jobID: job.id, data: envelope(#"{"dietComment":"d"}"#), statusCode: 200, error: nil)
            XCTAssertNil(store.job(id: job.id))
        }
        router.handle(jobID: UUID(), data: Data(), statusCode: 500, error: nil)
        XCTAssertTrue(recorder.notified.isEmpty)
        XCTAssertTrue(recorder.resent.isEmpty)
        XCTAssertTrue(recorder.events.isEmpty)
    }

    func testServerErrorWithinLimitIsResent() throws {
        let (router, store, recorder) = makeRouter()
        let job = ModelJob(kind: .mealAnalysis(pendingItemID: UUID()))
        try store.add(job, body: Data())
        router.handle(jobID: job.id, data: Data(), statusCode: 503, error: nil)
        XCTAssertEqual(recorder.resent.first?.attempt, 1)
        XCTAssertEqual(store.job(id: job.id)?.attempt, 1)
        XCTAssertTrue(recorder.meals.isEmpty)
        XCTAssertTrue(recorder.notified.isEmpty)
        XCTAssertEqual(recorder.events.map(\.0), ["model.retry"])
        XCTAssertEqual(recorder.events.first?.1["attempt"], "1")
    }

    func testServerErrorAfterLastAttemptFailsTheMeal() throws {
        let (router, store, recorder) = makeRouter()
        let itemID = UUID()
        let job = ModelJob(kind: .mealAnalysis(pendingItemID: itemID), attempt: ModelRetryPolicy.maxRetries)
        try store.add(job, body: Data())
        router.handle(jobID: job.id, data: Data(), statusCode: 503, error: nil)
        XCTAssertTrue(recorder.resent.isEmpty)
        XCTAssertEqual(recorder.meals.first?.0, itemID)
        guard case .failed = recorder.meals.first?.1 else { return XCTFail("expected failed") }
        XCTAssertNil(store.job(id: job.id))
        XCTAssertEqual(recorder.notified.first?.1, false)
        XCTAssertEqual(recorder.events.map(\.0), ["model.failed"])
        XCTAssertNotNil(recorder.events.first?.1["error"])
    }

    func testTimeoutIsResent() throws {
        let (router, store, recorder) = makeRouter()
        let job = ModelJob(kind: .dailyCoach(day: day))
        try store.add(job, body: Data())
        router.handle(jobID: job.id, data: Data(), statusCode: nil, error: URLError(.timedOut))
        XCTAssertEqual(recorder.resent.count, 1)
    }

    func testCancellationIsIgnored() throws {
        let (router, store, recorder) = makeRouter()
        let job = ModelJob(kind: .dailyCoach(day: day))
        try store.add(job, body: Data())
        router.handle(jobID: job.id, data: Data(), statusCode: nil, error: URLError(.cancelled))
        XCTAssertNotNil(store.job(id: job.id))
        XCTAssertTrue(recorder.resent.isEmpty)
        XCTAssertTrue(recorder.coach.isEmpty)
        XCTAssertTrue(recorder.notified.isEmpty)
        XCTAssertTrue(recorder.events.isEmpty)
    }

    func testUnknownJobIsIgnored() {
        let (router, _, recorder) = makeRouter()
        router.handle(jobID: UUID(), data: Data(), statusCode: 200, error: nil)
        XCTAssertTrue(recorder.notified.isEmpty)
        XCTAssertTrue(recorder.events.isEmpty)
    }

    func testUnreadableAnswerWithinLimitIsResent() throws {
        let (router, store, recorder) = makeRouter()
        let itemID = UUID()
        let job = ModelJob(kind: .mealAnalysis(pendingItemID: itemID))
        try store.add(job, body: Data())
        router.handle(jobID: job.id, data: envelope(""), statusCode: 200, error: nil)
        XCTAssertEqual(recorder.resent.first?.attempt, 1)
        XCTAssertEqual(store.job(id: job.id)?.attempt, 1)
        XCTAssertTrue(recorder.meals.isEmpty)
        XCTAssertTrue(recorder.notified.isEmpty)
        XCTAssertEqual(recorder.events.map(\.0), ["model.retry"])
        XCTAssertNotNil(recorder.events.first?.1["reason"])
    }

    func testNotFoodAnswerFailsTheMealWithoutRetrying() throws {
        let (router, store, recorder) = makeRouter()
        let itemID = UUID()
        let job = ModelJob(kind: .mealAnalysis(pendingItemID: itemID))
        try store.add(job, body: Data())
        router.handle(jobID: job.id, data: envelope(#"{"isFood":false,"dishName":"Not food","calories":0}"#),
                      statusCode: 200, error: nil)
        XCTAssertTrue(recorder.resent.isEmpty)
        XCTAssertNil(store.job(id: job.id))
        guard case .failed = recorder.meals.first?.1 else { return XCTFail("expected failed") }
        XCTAssertEqual(recorder.events.map(\.0), ["model.failed"])
    }

    func testUnparseableCoachRecordsFailure() throws {
        let (router, store, recorder) = makeRouter()
        let kind = ModelJobKind.dailyCoach(day: day)
        let job = ModelJob(kind: kind, attempt: ModelRetryPolicy.maxRetries)
        try store.add(job, body: Data())
        router.handle(jobID: job.id, data: Data("not json".utf8), statusCode: 200, error: nil)
        XCTAssertNotNil(store.failures[kind])
        XCTAssertNil(store.job(id: job.id))
        XCTAssertEqual(recorder.notified.first?.1, false)
    }
}
