import XCTest
import CoreData
@testable import NutriTrack

@MainActor
final class EvaluationTextsTests: XCTestCase {

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    func testTodayEvaluationReturnsNilWhenEmpty() {
        let ctx = Persistence(inMemory: true).container.viewContext
        XCTAssertNil(EvaluationService.todayEvaluation(in: ctx))
    }

    func testCoachTextOnEmptyDayCreatesEvaluation() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        EvaluationService.saveCoachText("Eat more fibre.", day: today, in: ctx)
        let evaluation = try XCTUnwrap(EvaluationService.evaluation(for: today, in: ctx))
        XCTAssertEqual(evaluation.coachText, "Eat more fibre.")
        XCTAssertNotNil(evaluation.coachGeneratedAt)
        XCTAssertNil(evaluation.closedAt)
    }

    func testCoachTextReusesTheClosedDay() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let entry = FoodEntry(context: ctx)
        entry.id = UUID()
        entry.timestamp = Date()
        entry.calories = 500
        try ctx.save()
        EvaluationService.closeDay(Date(), isLogComplete: true, in: ctx)
        EvaluationService.saveCoachText("Good day.", day: today, in: ctx)
        let all = try ctx.fetch(DailyEvaluation.fetchRequest())
        XCTAssertEqual(all.count, 1)
        XCTAssertNotNil(all.first?.closedAt)
        XCTAssertEqual(all.first?.coachText, "Good day.")
    }
}
