import XCTest
import CoreData
@testable import NutriTrack

@MainActor
final class EvaluationTextsTests: XCTestCase {

    private func score(_ value: Int) -> HealthScore { HealthScore(value: value, components: []) }
    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var yesterday: Date { Calendar.current.date(byAdding: .day, value: -1, to: today)! }

    private func allEvaluations(_ ctx: NSManagedObjectContext) throws -> [DailyEvaluation] {
        try ctx.fetch(DailyEvaluation.fetchRequest())
    }

    func testCoachTextOnEmptyDayCreatesEvaluationWithoutScores() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        EvaluationService.saveCoachText("Eat more fibre.", day: today, in: ctx)
        let evaluation = try XCTUnwrap(EvaluationService.evaluation(for: today, in: ctx))
        XCTAssertEqual(evaluation.coachText, "Eat more fibre.")
        XCTAssertNotNil(evaluation.coachGeneratedAt)
        XCTAssertNil(evaluation.generatedAt)
    }

    func testCoachTextReusesScoredEvaluation() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        EvaluationService.upsert(sleep: score(70), readiness: score(90), in: ctx)
        EvaluationService.saveCoachText("Good day.", day: today, in: ctx)
        let all = try allEvaluations(ctx)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.sleepScore, 70)
        XCTAssertEqual(all.first?.coachText, "Good day.")
    }

    func testScoreTextsAreWrittenWithoutTouchingScores() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        EvaluationService.upsert(sleep: score(70), readiness: score(90), in: ctx)
        let texts = ScoreEvaluationTexts(sleepComment: "s", readinessComment: "r")
        EvaluationService.applyScoreTexts(texts, day: today, in: ctx)
        let evaluation = try XCTUnwrap(EvaluationService.evaluation(for: today, in: ctx))
        XCTAssertEqual(evaluation.readinessText, "r")
        XCTAssertEqual(evaluation.sleepScore, 70)
    }

    func testScoreTextsTargetTheJobDayNotToday() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let texts = ScoreEvaluationTexts(sleepComment: "s", readinessComment: "r")
        EvaluationService.applyScoreTexts(texts, day: yesterday, in: ctx)
        XCTAssertEqual(EvaluationService.evaluation(for: yesterday, in: ctx)?.sleepText, "s")
        XCTAssertNil(EvaluationService.evaluation(for: today, in: ctx))
    }

    func testHistoryExcludesCoachOnlyEvaluations() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        EvaluationService.saveCoachText("x", day: yesterday, in: ctx)
        EvaluationService.upsert(sleep: score(70), readiness: score(90), in: ctx)
        let request = DailyEvaluation.fetchRequest()
        request.predicate = EvaluationService.historyPredicate(since: Calendar.current.date(byAdding: .day, value: -14, to: today)!)
        XCTAssertEqual(try ctx.fetch(request).count, 1)
    }

    func testDietTextIsSavedOnTheDayOfTheJob() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        EvaluationService.saveDietText("More fibre.", day: yesterday, in: ctx)
        XCTAssertEqual(EvaluationService.evaluation(for: yesterday, in: ctx)?.dietText, "More fibre.")
        XCTAssertNil(EvaluationService.evaluation(for: today, in: ctx))
    }
}
