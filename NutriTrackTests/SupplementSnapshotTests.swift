import XCTest
import CoreData
@testable import NutriTrack

final class SupplementSnapshotTests: XCTestCase {

    func testSnapshotSurvivesTemplateDeletion() {
        let ctx = Persistence(inMemory: true).container.viewContext

        let template = SupplementTemplate(context: ctx)
        template.id = UUID()
        template.name = "Test Multi"
        template.calories = 50
        template.vitaminCMg = 80
        template.zincMg = 10

        SupplementLog.log(template: template, doses: 2, in: ctx)

        let fetchRequest = SupplementLog.fetchRequest()
        var logs = try! ctx.fetch(fetchRequest)
        XCTAssertEqual(logs.count, 1)

        var snapshot = logs[0].snapshotNutrients
        XCTAssertEqual(logs[0].name, "Test Multi")
        XCTAssertEqual(snapshot?.calories, 100)
        XCTAssertEqual(snapshot?.vitaminCMg, 160)
        XCTAssertEqual(snapshot?.zincMg, 20)

        ctx.delete(template)
        try! ctx.save()

        logs = try! ctx.fetch(fetchRequest)
        XCTAssertEqual(logs.count, 1)

        snapshot = logs[0].snapshotNutrients
        XCTAssertEqual(logs[0].name, "Test Multi")
        XCTAssertEqual(snapshot?.calories, 100)
        XCTAssertEqual(snapshot?.vitaminCMg, 160)
        XCTAssertEqual(snapshot?.zincMg, 20)
    }

    func testCorruptNutrientsJsonReturnsNilWithoutCrashing() {
        let ctx = Persistence(inMemory: true).container.viewContext

        let entry = SupplementLog(context: ctx)
        entry.id = UUID()
        entry.timestamp = Date()
        entry.doses = 1
        entry.templateID = ""
        entry.nutrientsJson = "not valid json"

        XCTAssertNil(entry.snapshotNutrients)
    }

    private func makeTemplate(in ctx: NSManagedObjectContext) -> SupplementTemplate {
        let template = SupplementTemplate(context: ctx)
        template.id = UUID()
        template.name = "Electrolytes"
        template.calories = 20
        template.sodiumMg = 300
        template.fiberG = 2
        template.sugarG = 4
        template.potassiumMg = 150
        template.phosphorusMg = 50
        template.vitaminAUg = 100
        template.vitaminCMg = 80
        return template
    }

    private func onlyLog(in ctx: NSManagedObjectContext) throws -> SupplementLog {
        try XCTUnwrap(try ctx.fetch(SupplementLog.fetchRequest()).first)
    }

    func testSnapshotCarriesSodiumFiberAndSugar() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        SupplementLog.log(template: makeTemplate(in: ctx), doses: 2, in: ctx)
        let snapshot = try XCTUnwrap(try onlyLog(in: ctx).snapshotNutrients)
        XCTAssertEqual(snapshot.sodiumMg, 600)
        XCTAssertEqual(snapshot.fiberG, 4)
        XCTAssertEqual(snapshot.sugarG, 8)
        XCTAssertEqual(snapshot.potassiumMg, 300)
        XCTAssertEqual(snapshot.phosphorusMg, 100)
        XCTAssertEqual(snapshot.vitaminAUg, 200)
        XCTAssertEqual(snapshot.dishName, "Electrolytes")
    }

    func testChangingDosesRescalesTheSnapshot() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let template = makeTemplate(in: ctx)
        SupplementLog.log(template: template, doses: 1, in: ctx)
        let log = try onlyLog(in: ctx)
        ctx.delete(template)
        try ctx.save()

        log.setDoses(2.5, in: ctx)
        XCTAssertEqual(log.doses, 2.5)
        XCTAssertEqual(log.snapshotNutrients?.vitaminCMg ?? 0, 200, accuracy: 0.0001)
        XCTAssertEqual(log.snapshotNutrients?.sodiumMg ?? 0, 750, accuracy: 0.0001)
    }

    func testDosesStayBetweenHalfAndTenInHalfSteps() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        SupplementLog.log(template: makeTemplate(in: ctx), doses: 1, in: ctx)
        let log = try onlyLog(in: ctx)
        log.setDoses(0, in: ctx)
        XCTAssertEqual(log.doses, 0.5)
        log.setDoses(99, in: ctx)
        XCTAssertEqual(log.doses, 10)
        log.setDoses(1.3, in: ctx)
        XCTAssertEqual(log.doses, 1.5)
        XCTAssertEqual(log.snapshotNutrients?.vitaminCMg ?? 0, 120, accuracy: 0.0001)
    }

    func testNegativeTemplateValuesAreClearedOnClamp() {
        let ctx = Persistence(inMemory: true).container.viewContext
        let template = makeTemplate(in: ctx)
        template.sodiumMg = -5
        template.vitaminAUg = -1
        template.clampNutrients()
        XCTAssertEqual(template.sodiumMg, 0)
        XCTAssertEqual(template.vitaminAUg, 0)
        XCTAssertEqual(template.vitaminCMg, 80)
    }
}
