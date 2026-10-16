import XCTest
import CoreData
@testable import NutriTrack

final class DailyEvaluationTests: XCTestCase {

    private func makeScore(_ value: Int) -> HealthScore {
        HealthScore(value: value, components: [])
    }

    func testTodayEvaluationReturnsNilWhenEmpty() {
        let ctx = Persistence(inMemory: true).container.viewContext
        XCTAssertNil(EvaluationService.todayEvaluation(in: ctx))
    }

    func testTodayEvaluationReturnsEntityAfterUpsert() {
        let ctx = Persistence(inMemory: true).container.viewContext

        EvaluationService.upsert(sleep: makeScore(70), readiness: makeScore(90), in: ctx)

        let evaluation = EvaluationService.todayEvaluation(in: ctx)
        XCTAssertNotNil(evaluation)
        XCTAssertEqual(evaluation?.sleepScore, 70)
        XCTAssertEqual(evaluation?.readinessScore, 90)
        XCTAssertEqual(evaluation?.dietScore, 0)
        XCTAssertNil(evaluation?.closedAt)
    }

    func testUpsertUpdatesSingleEntityInsteadOfCreatingSecond() {
        let ctx = Persistence(inMemory: true).container.viewContext

        EvaluationService.upsert(sleep: makeScore(50), readiness: makeScore(50), in: ctx)
        EvaluationService.upsert(sleep: makeScore(88), readiness: makeScore(66), in: ctx)

        let all = try! ctx.fetch(DailyEvaluation.fetchRequest())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].sleepScore, 88)
        XCTAssertEqual(all[0].readinessScore, 66)
    }

    func testUpsertPreservesExistingTexts() {
        let ctx = Persistence(inMemory: true).container.viewContext
        let texts = ScoreEvaluationTexts(sleepComment: "a", readinessComment: "c")

        EvaluationService.upsert(sleep: makeScore(10), readiness: makeScore(10), in: ctx)
        EvaluationService.applyScoreTexts(texts, day: Date(), in: ctx)
        EvaluationService.saveDietText("b", day: Date(), in: ctx)
        EvaluationService.upsert(sleep: makeScore(20), readiness: makeScore(20), in: ctx)

        let evaluation = EvaluationService.todayEvaluation(in: ctx)
        XCTAssertEqual(evaluation?.sleepText, "a")
        XCTAssertEqual(evaluation?.dietText, "b")
        XCTAssertEqual(evaluation?.readinessText, "c")
        XCTAssertEqual(evaluation?.sleepScore, 20)
        XCTAssertEqual(evaluation?.readinessScore, 20)
    }

    func testScoreTextsNeverWriteTheDietText() {
        let ctx = Persistence(inMemory: true).container.viewContext
        EvaluationService.applyScoreTexts(ScoreEvaluationTexts(sleepComment: "a", readinessComment: "c"),
                                          day: Date(), in: ctx)
        XCTAssertNil(EvaluationService.todayEvaluation(in: ctx)?.dietText)
    }
}
