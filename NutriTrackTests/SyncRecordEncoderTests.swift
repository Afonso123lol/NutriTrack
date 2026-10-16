import XCTest
import CoreData
@testable import NutriTrack

@MainActor
final class SyncRecordEncoderTests: XCTestCase {

    private func makeContext() -> NSManagedObjectContext {
        Persistence(inMemory: true).container.viewContext
    }

    func testTimestampIsUTCWithFractionalSeconds() {
        XCTAssertEqual(SyncRecordEncoder.timestamp(Date(timeIntervalSince1970: 0.5)), "1970-01-01T00:00:00.500Z")
    }

    func testFoodEntrySkipsBinaryAndFlagsThePhoto() {
        let ctx = makeContext()
        let entry = FoodEntry(context: ctx)
        let id = UUID()
        entry.id = id
        entry.timestamp = Date(timeIntervalSince1970: 0.5)
        entry.dishName = "Grilled chicken"
        entry.calories = 520
        entry.photoData = Data([0xFF, 0xD8, 0xFF])
        let payload = SyncRecordEncoder.payload(for: entry)
        XCTAssertNil(payload["photoData"])
        XCTAssertEqual(payload["hasPhoto"] as? Bool, true)
        XCTAssertEqual(payload["id"] as? String, id.uuidString)
        XCTAssertEqual(payload["timestamp"] as? String, "1970-01-01T00:00:00.500Z")
        XCTAssertEqual(payload["dishName"] as? String, "Grilled chicken")
        XCTAssertEqual(payload["calories"] as? Double, 520)
    }

    func testEntryWithoutPhotoIsFlaggedFalse() {
        let entry = FoodEntry(context: makeContext())
        entry.id = UUID()
        XCTAssertEqual(SyncRecordEncoder.payload(for: entry)["hasPhoto"] as? Bool, false)
    }

    func testOtherEntitiesHaveNoPhotoFlag() {
        let weight = WeightEntry(context: makeContext())
        weight.id = UUID()
        weight.weightKg = 80.5
        let payload = SyncRecordEncoder.payload(for: weight)
        XCTAssertNil(payload["hasPhoto"])
        XCTAssertEqual(payload["weightKg"] as? Double, 80.5)
    }

    func testNilAttributesAreOmitted() {
        let evaluation = DailyEvaluation(context: makeContext())
        evaluation.id = UUID()
        evaluation.sleepScore = 83
        let payload = SyncRecordEncoder.payload(for: evaluation)
        XCTAssertNil(payload["coachText"])
        XCTAssertEqual(payload["sleepScore"] as? Int, 83)
    }

    func testNonFiniteNumbersBecomeNull() {
        let entry = FoodEntry(context: makeContext())
        entry.id = UUID()
        entry.calories = .nan
        let payload = SyncRecordEncoder.payload(for: entry)
        XCTAssertTrue(payload["calories"] is NSNull)
        XCTAssertTrue(JSONSerialization.isValidJSONObject(payload))
    }

    func testEveryEntityEncodesToValidJSON() {
        let ctx = makeContext()
        for entity in SyncEntities.all {
            let object = NSEntityDescription.insertNewObject(forEntityName: entity, into: ctx)
            object.setValue(UUID(), forKey: "id")
            let payload = SyncRecordEncoder.payload(for: object)
            XCTAssertTrue(JSONSerialization.isValidJSONObject(payload), entity)
            XCTAssertNotNil(payload["id"], entity)
        }
    }

    func testBooleansAreSentAsTrueAndFalseAndThumbnailsStayHome() throws {
        let ctx = makeContext()
        let entry = FoodEntry(context: ctx)
        entry.id = UUID()
        entry.wasEdited = true
        entry.thumbnailData = Data([0xFF, 0xD8, 0xFF])
        let payload = SyncRecordEncoder.payload(for: entry)
        XCTAssertNil(payload["thumbnailData"])
        let json = String(decoding: try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), as: UTF8.self)
        XCTAssertTrue(json.contains(#""wasEdited":true"#))

        let evaluation = DailyEvaluation(context: ctx)
        evaluation.id = UUID()
        let evaluationJSON = String(decoding: try JSONSerialization.data(withJSONObject: SyncRecordEncoder.payload(for: evaluation)), as: UTF8.self)
        XCTAssertTrue(evaluationJSON.contains(#""isLogComplete":false"#))
    }

    func testVersionSixFieldsAreSent() {
        let ctx = makeContext()
        let checkIn = DailyCheckIn(context: ctx)
        checkIn.id = UUID()
        checkIn.soreness = 2
        checkIn.stress = 4
        checkIn.dayEnergy = 3
        checkIn.suggestionChoice = "kept"
        let sent = SyncRecordEncoder.payload(for: checkIn)
        XCTAssertEqual(sent["soreness"] as? Int, 2)
        XCTAssertEqual(sent["stress"] as? Int, 4)
        XCTAssertEqual(sent["dayEnergy"] as? Int, 3)
        XCTAssertEqual(sent["suggestionChoice"] as? String, "kept")

        let profile = UserProfile(context: ctx)
        profile.id = UUID()
        let profilePayload = SyncRecordEncoder.payload(for: profile)
        XCTAssertEqual(profilePayload["sleepNeedHours"] as? Double, 8)
        XCTAssertEqual(profilePayload["yellowMode"] as? String, "suggest")
        XCTAssertNil(profilePayload["calibrationStartedAt"])
    }
}
