import XCTest
@testable import NutriTrack

@MainActor
final class ModelJobStoreTests: XCTestCase {

    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("jobs-\(UUID().uuidString)", isDirectory: true)
    }

    func testAddedJobSurvivesReloadWithBody() throws {
        let dir = tempDirectory()
        let job = ModelJob(kind: .dailyCoach(day: Calendar.current.startOfDay(for: Date())))
        try ModelJobStore(directory: dir).add(job, body: Data("body".utf8))

        let reloaded = ModelJobStore(directory: dir)
        XCTAssertEqual(reloaded.jobs, [job])
        XCTAssertEqual(try Data(contentsOf: reloaded.bodyURL(for: job.id)), Data("body".utf8))
    }

    func testUpdatePersistsAttempt() throws {
        let dir = tempDirectory()
        let store = ModelJobStore(directory: dir)
        var job = ModelJob(kind: .mealAnalysis(pendingItemID: UUID()))
        try store.add(job, body: Data())
        job.attempt = 2
        store.update(job)
        XCTAssertEqual(ModelJobStore(directory: dir).job(id: job.id)?.attempt, 2)
    }

    func testRemoveDeletesFiles() throws {
        let dir = tempDirectory()
        let store = ModelJobStore(directory: dir)
        let job = ModelJob(kind: .mealAnalysis(pendingItemID: UUID()))
        try store.add(job, body: Data("x".utf8))
        store.remove(id: job.id)
        XCTAssertNil(store.job(id: job.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.bodyURL(for: job.id).path))
        XCTAssertTrue(ModelJobStore(directory: dir).jobs.isEmpty)
    }

    func testIsPendingMatchesKind() throws {
        let store = ModelJobStore(directory: tempDirectory())
        let day = Calendar.current.startOfDay(for: Date())
        try store.add(ModelJob(kind: .scoreEvaluation(day: day)), body: Data())
        XCTAssertTrue(store.isPending(.scoreEvaluation(day: day)))
        XCTAssertFalse(store.isPending(.dailyCoach(day: day)))
    }

    func testAddingJobClearsPreviousFailureOfSameKind() throws {
        let store = ModelJobStore(directory: tempDirectory())
        let kind = ModelJobKind.dailyCoach(day: Calendar.current.startOfDay(for: Date()))
        store.recordFailure("boom", for: kind)
        XCTAssertEqual(store.failures[kind], "boom")
        try store.add(ModelJob(kind: kind), body: Data())
        XCTAssertNil(store.failures[kind])
    }
}
