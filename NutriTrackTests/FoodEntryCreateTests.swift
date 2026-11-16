import XCTest
import CoreData
import UIKit
@testable import NutriTrack

@MainActor
final class FoodEntryCreateTests: XCTestCase {

    private func sampleAnalysis() throws -> NutritionAnalysis {
        let json = #"{"dishName":"Grilled chicken with rice","calories":520,"proteinG":42,"carbsG":55,"fatG":12,"saturatedFatG":3.5,"omega3G":0.4,"fiberG":2.1,"sugarG":1.5,"sodiumMg":680,"potassiumMg":900,"calciumMg":45,"ironMg":3.5,"zincMg":4.2,"magnesiumMg":85,"phosphorusMg":320,"seleniumUg":28,"copperUg":120,"vitaminCMg":15,"vitaminDUg":0.8,"vitaminEMg":1.2,"vitaminKUg":35,"vitaminB1Mg":0.4,"vitaminB2Mg":0.3,"vitaminB3Mg":12,"vitaminB5Mg":1.8,"vitaminB6Mg":0.9,"vitaminB12Ug":1.8,"folateUg":42}"#
        return try JSONDecoder().decode(NutritionAnalysis.self, from: Data(json.utf8))
    }

    private func image(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func testMealWithoutPhotoKeepsNoImageAndTheGivenTime() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let eatenAt = Date(timeIntervalSince1970: 1_800_000_000)
        let entry = FoodEntry.create(from: try sampleAnalysis(), image: nil, note: "2 chorizo rolls",
                                     timestamp: eatenAt, in: ctx)
        XCTAssertNil(entry.photoData)
        XCTAssertNil(entry.thumbnailData)
        XCTAssertEqual(entry.timestamp, eatenAt)
        XCTAssertEqual(entry.note, "2 chorizo rolls")
    }

    func testChangingTheTimeMovesTheMeal() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let entry = FoodEntry.create(from: try sampleAnalysis(), image: nil, note: nil,
                                     timestamp: Date(timeIntervalSince1970: 1_800_000_000), in: ctx)
        let lunch = Date(timeIntervalSince1970: 1_800_000_000 - 5 * 3600)
        entry.changeTime(to: lunch, in: ctx)
        XCTAssertEqual(entry.timestamp, lunch)
        XCTAssertFalse(ctx.hasChanges)
        XCTAssertEqual(entry.calories, 520)
    }

    func testPhotoIsStoredAtTheSizeSentToTheModel() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        FoodEntry.create(from: try sampleAnalysis(), image: image(width: 3000, height: 2000), note: nil, in: ctx)
        let entry = try XCTUnwrap(try ctx.fetch(FoodEntry.fetchRequest()).first)
        let stored = try XCTUnwrap(UIImage(data: try XCTUnwrap(entry.photoData)))
        XCTAssertEqual(stored.size.width * stored.scale, 1024, accuracy: 1)
        XCTAssertEqual(stored.size.height * stored.scale, 683, accuracy: 1)
    }

    func testTimestampIsTheCaptureTime() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let captured = Date(timeIntervalSince1970: 1_000_000)
        FoodEntry.create(from: try sampleAnalysis(), image: image(width: 10, height: 10), note: nil,
                         timestamp: captured, in: ctx)
        let entry = try XCTUnwrap(try ctx.fetch(FoodEntry.fetchRequest()).first)
        XCTAssertEqual(entry.timestamp, captured)
    }

    func testAnalysisRoundTripsThroughTheEntry() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        var analysis = try sampleAnalysis()
        analysis.alcoholG = 12
        analysis.transFatG = 0.3
        FoodEntry.create(from: analysis, image: image(width: 10, height: 10), note: nil, in: ctx)
        let entry = try XCTUnwrap(try ctx.fetch(FoodEntry.fetchRequest()).first)
        XCTAssertEqual(entry.alcoholG, 12)
        let back = entry.analysis
        XCTAssertEqual(back.dishName, "Grilled chicken with rice")
        XCTAssertEqual(back.calories, 520)
        XCTAssertEqual(back.folateUg, 42)
        XCTAssertEqual(back.alcoholG, 12)
        XCTAssertEqual(back.transFatG, 0.3)
    }

    private func makeEntry(in ctx: NSManagedObjectContext, timestamp: Date = Date()) throws -> FoodEntry {
        FoodEntry.create(from: try sampleAnalysis(), image: image(width: 800, height: 600), note: "lunch",
                         timestamp: timestamp, in: ctx)
    }

    private func longestSide(_ data: Data?) throws -> CGFloat {
        let stored = try XCTUnwrap(UIImage(data: try XCTUnwrap(data)))
        return max(stored.size.width, stored.size.height) * stored.scale
    }

    func testCreateStoresAThumbnailAndTheEditedMark() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let entry = try makeEntry(in: ctx)
        XCTAssertEqual(try longestSide(entry.thumbnailData), 216, accuracy: 1)
        XCTAssertFalse(entry.wasEdited)

        let edited = FoodEntry.create(from: try sampleAnalysis(), image: image(width: 10, height: 10), note: nil,
                                      wasEdited: true, in: ctx)
        XCTAssertTrue(edited.wasEdited)
    }

    func testLogAgainCopiesTheMealWithAMultiplier() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let source = try makeEntry(in: ctx, timestamp: Date(timeIntervalSince1970: 1_000_000))
        let now = Date(timeIntervalSince1970: 2_000_000)
        let copy = FoodEntry.logAgain(source, multiplier: 1.5, now: now, in: ctx)

        XCTAssertNotEqual(copy.id, source.id)
        XCTAssertEqual(copy.sourceEntryID, source.id)
        XCTAssertEqual(copy.timestamp, now)
        XCTAssertEqual(copy.dishName, source.dishName)
        XCTAssertEqual(copy.note, "lunch")
        XCTAssertEqual(copy.calories, 780)
        XCTAssertEqual(copy.proteinG, 63)
        XCTAssertEqual(copy.folateUg, 63)
        XCTAssertEqual(copy.photoData, source.photoData)
        XCTAssertEqual(copy.thumbnailData, source.thumbnailData)
        XCTAssertFalse(copy.wasEdited)
        XCTAssertEqual(try ctx.fetch(FoodEntry.fetchRequest()).count, 2)
    }

    func testLogAgainRespectsThePerMealMaximums() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let copy = FoodEntry.logAgain(try makeEntry(in: ctx), multiplier: 10, in: ctx)
        XCTAssertEqual(copy.proteinG, 300)
        XCTAssertEqual(copy.calories, 5200)
    }

    func testApplyEditWritesTheValuesAndMarksTheEntry() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let entry = try makeEntry(in: ctx)
        var edited = entry.analysis
        edited.dishName = "Chicken, less rice"
        edited.calories = 430
        edited.carbsG = 35
        entry.applyEdit(edited, in: ctx)
        XCTAssertEqual(entry.dishName, "Chicken, less rice")
        XCTAssertEqual(entry.calories, 430)
        XCTAssertEqual(entry.carbsG, 35)
        XCTAssertTrue(entry.wasEdited)
        XCTAssertFalse(ctx.hasChanges)
    }

    func testRemoveDeletesTheEntry() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        try makeEntry(in: ctx).remove(from: ctx)
        XCTAssertTrue(try ctx.fetch(FoodEntry.fetchRequest()).isEmpty)
    }

    func testRemovingTheLastMealReopensAClosedDay() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let entry = try makeEntry(in: ctx)
        EvaluationService.closeDay(Date(), isLogComplete: true, in: ctx)
        FoodEntry.logAgain(entry, multiplier: 2, in: ctx)
        XCTAssertNotNil(try XCTUnwrap(EvaluationService.todayEvaluation(in: ctx)).closedAt)

        for meal in try ctx.fetch(FoodEntry.fetchRequest()) { meal.remove(from: ctx) }
        XCTAssertNil(try XCTUnwrap(EvaluationService.todayEvaluation(in: ctx)).closedAt)
    }

    func testBackfillGivesOldMealsAThumbnail() async throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let old = try makeEntry(in: ctx)
        old.thumbnailData = nil
        let withoutPhoto = try makeEntry(in: ctx)
        withoutPhoto.photoData = nil
        withoutPhoto.thumbnailData = nil
        try ctx.save()

        await FoodEntry.backfillThumbnails(in: ctx)
        XCTAssertEqual(try longestSide(old.thumbnailData), 216, accuracy: 1)
        XCTAssertNil(withoutPhoto.thumbnailData)
        XCTAssertFalse(ctx.hasChanges)
    }

    func testHistoryCutoffIsTheStartOfTheDayThirtyDaysBack() {
        let now = Date()
        let cutoff = FoodEntry.historyCutoff(days: 30, now: now)
        let expected = Calendar.current.date(byAdding: .day, value: -30, to: Calendar.current.startOfDay(for: now))
        XCTAssertEqual(cutoff, expected)
    }
}
