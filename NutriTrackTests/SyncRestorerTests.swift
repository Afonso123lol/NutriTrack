import XCTest
import CoreData
@testable import NutriTrack

@MainActor
final class SyncRestorerTests: XCTestCase {

    private func record(of object: NSManagedObject, updatedAt: String = "2026-10-07T08:00:00.000000Z") throws -> RestoreRecord {
        RestoreRecord(entity: try XCTUnwrap(object.entity.name), id: try XCTUnwrap(object.value(forKey: "id") as? UUID),
                      updatedAt: updatedAt, payload: SyncRecordEncoder.payload(for: object))
    }

    func testMealComesBackWithEveryValue() throws {
        let source = Persistence(inMemory: true).container.viewContext
        let meal = FoodEntry(context: source)
        meal.id = UUID()
        meal.dishName = "Pão com chouriço"
        meal.calories = 520
        meal.proteinG = 19
        meal.note = "2 rolls"
        meal.wasEdited = true
        meal.timestamp = Date(timeIntervalSince1970: 1_800_000_000.25)
        meal.photoData = Data([1, 2, 3])
        let sent = try record(of: meal)

        let target = Persistence(inMemory: true).container.viewContext
        let photos = SyncRestorer.importRecords([sent], into: target)
        let restored = try XCTUnwrap(try target.fetch(FoodEntry.fetchRequest()).first)
        XCTAssertEqual(restored.id, meal.id)
        XCTAssertEqual(restored.dishName, "Pão com chouriço")
        XCTAssertEqual(restored.calories, 520)
        XCTAssertEqual(restored.proteinG, 19)
        XCTAssertEqual(restored.note, "2 rolls")
        XCTAssertTrue(restored.wasEdited)
        XCTAssertEqual(try XCTUnwrap(restored.timestamp).timeIntervalSince1970, 1_800_000_000.25, accuracy: 0.001)
        XCTAssertNil(restored.photoData)
        XCTAssertEqual(photos, [try XCTUnwrap(meal.id)])
    }

    func testProfileKeepsItsNumbersAndDates() throws {
        let source = Persistence(inMemory: true).container.viewContext
        let profile = UserProfile(context: source)
        profile.id = UUID()
        profile.name = "Afonso"
        profile.age = 22
        profile.weightKg = 75.4
        profile.goal = "recomp"
        profile.birthDate = Date(timeIntervalSince1970: 1_080_000_000)
        let sent = try record(of: profile)

        let target = Persistence(inMemory: true).container.viewContext
        XCTAssertTrue(SyncRestorer.importRecords([sent], into: target).isEmpty)
        let restored = try XCTUnwrap(try target.fetch(UserProfile.fetchRequest()).first)
        XCTAssertEqual(restored.name, "Afonso")
        XCTAssertEqual(restored.age, 22)
        XCTAssertEqual(restored.weightKg, 75.4)
        XCTAssertEqual(restored.goalEnum, .recomp)
        XCTAssertEqual(restored.birthDate, Date(timeIntervalSince1970: 1_080_000_000))
    }

    func testOnlyTheNewestProfileIsRestored() throws {
        let source = Persistence(inMemory: true).container.viewContext
        let older = UserProfile(context: source)
        older.id = UUID()
        older.name = "Old"
        let newer = UserProfile(context: source)
        newer.id = UUID()
        newer.name = "New"
        let records = [try record(of: newer, updatedAt: "2026-10-12T08:00:00.000000Z"),
                       try record(of: older, updatedAt: "2026-10-06T23:25:22.928000Z")]

        let target = Persistence(inMemory: true).container.viewContext
        SyncRestorer.importRecords(records, into: target)
        XCTAssertEqual(try target.fetch(UserProfile.fetchRequest()).map(\.name), ["New"])
    }

    func testAnExistingProfileIsKept() throws {
        let source = Persistence(inMemory: true).container.viewContext
        let remote = UserProfile(context: source)
        remote.id = UUID()
        remote.name = "Remote"
        let target = Persistence(inMemory: true).container.viewContext
        let local = UserProfile(context: target)
        local.id = UUID()
        local.name = "Local"
        SyncRestorer.importRecords([try record(of: remote)], into: target)
        XCTAssertEqual(try target.fetch(UserProfile.fetchRequest()).map(\.name), ["Local"])
    }

    func testRecordsAlreadyPresentAndUnknownEntitiesAreSkipped() throws {
        let target = Persistence(inMemory: true).container.viewContext
        let weighIn = WeightEntry(context: target)
        weighIn.id = UUID()
        weighIn.weightKg = 75
        let duplicate = RestoreRecord(entity: "WeightEntry", id: try XCTUnwrap(weighIn.id),
                                      updatedAt: "2026-10-07T08:00:00.000000Z", payload: ["weightKg": 99.0])
        let unknown = RestoreRecord(entity: "Hacker", id: UUID(), updatedAt: "2026-10-07T08:00:00.000000Z", payload: [:])
        let fresh = RestoreRecord(entity: "WeightEntry", id: UUID(), updatedAt: "2026-10-07T08:00:00.000000Z",
                                  payload: ["weightKg": 76.2, "date": "2026-10-07T07:30:00.000Z"])
        SyncRestorer.importRecords([duplicate, unknown, fresh], into: target)
        let weights = try target.fetch(WeightEntry.fetchRequest()).map(\.weightKg).sorted()
        XCTAssertEqual(weights, [75, 76.2])
    }

    func testPageIsParsedWithItsCursor() throws {
        let id = UUID()
        let json = """
        {"records":[{"entity":"WeightEntry","id":"\(id.uuidString.lowercased())","updatedAt":"2026-10-07T08:00:00.000000Z","payload":{"weightKg":75.4}},
                    {"entity":"WeightEntry","id":"not-a-uuid","updatedAt":"x","payload":{}}],"next":17}
        """
        let page = try SyncRestorer.parsePage(Data(json.utf8))
        XCTAssertEqual(page.next, 17)
        XCTAssertEqual(page.records.map(\.id), [id])
        XCTAssertEqual(page.records.first?.payload["weightKg"] as? Double, 75.4)
        XCTAssertNil(try SyncRestorer.parsePage(Data(#"{"records":[],"next":null}"#.utf8)).next)
        XCTAssertThrowsError(try SyncRestorer.parsePage(Data("nope".utf8)))
    }

    func testClientWalksEveryPageWithTheToken() async throws {
        let config = try XCTUnwrap(SyncConfig(info: ["SYNC_BASE_URL": "https://vps.example.ts.net", "SYNC_TOKEN": "secret-token"]))
        var requested: [String] = []
        let first = UUID(), second = UUID()
        let client = SyncRestoreClient(config: config) { request in
            let url = try XCTUnwrap(request.url)
            requested.append(url.absoluteString)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
            XCTAssertEqual(request.httpMethod, "GET")
            let isFirst = url.query?.contains("after=0") ?? false
            let body = isFirst
                ? #"{"records":[{"entity":"WeightEntry","id":"\#(first.uuidString)","updatedAt":"a","payload":{}}],"next":5}"#
                : #"{"records":[{"entity":"WeightEntry","id":"\#(second.uuidString)","updatedAt":"b","payload":{}}],"next":null}"#
            return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let records = try await client.allRecords()
        XCTAssertEqual(records.map(\.id), [first, second])
        XCTAssertEqual(requested, ["https://vps.example.ts.net/v1/records?after=0&limit=200",
                                   "https://vps.example.ts.net/v1/records?after=5&limit=200"])
    }

    func testClientTurnsARefusalIntoAnError() async throws {
        let config = try XCTUnwrap(SyncConfig(info: ["SYNC_BASE_URL": "https://vps.example.ts.net", "SYNC_TOKEN": "secret-token"]))
        let client = SyncRestoreClient(config: config) { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!)
        }
        do {
            _ = try await client.allRecords()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? RestoreError, .server(401))
        }
    }

    func testPhotoIsAttachedWithAThumbnail() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let meal = FoodEntry(context: ctx)
        let id = UUID()
        meal.id = id
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let jpeg = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600), format: format).image { c in
            UIColor.red.setFill()
            c.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
        }.jpegData(compressionQuality: 0.8))
        SyncRestorer.attachPhoto(jpeg, to: id, in: ctx)
        XCTAssertEqual(meal.photoData, jpeg)
        let thumbnail = try XCTUnwrap(meal.thumbnailData.flatMap(UIImage.init(data:)))
        XCTAssertLessThanOrEqual(max(thumbnail.size.width, thumbnail.size.height), FoodEntry.thumbnailDimension)
    }

    func testCheckInComesBackWithTheVersionSixFields() throws {
        let source = Persistence(inMemory: true).container.viewContext
        let wokeAt = Date(timeIntervalSince1970: 1_790_000_000)
        let checkIn = DailyCheckIn(context: source)
        checkIn.id = UUID()
        checkIn.date = Calendar.current.startOfDay(for: wokeAt)
        checkIn.energyLevel = 4
        checkIn.soreness = 2
        checkIn.stress = 5
        checkIn.dayEnergy = 3
        checkIn.wakeTime = wokeAt
        let profile = UserProfile(context: source)
        profile.id = UUID()
        profile.sleepNeedHours = 8.5

        let target = Persistence(inMemory: true).container.viewContext
        _ = SyncRestorer.importRecords([try record(of: checkIn), try record(of: profile)], into: target)

        let restored = try XCTUnwrap(try target.fetch(DailyCheckIn.fetchRequest()).first)
        XCTAssertEqual(restored.soreness, 2)
        XCTAssertEqual(restored.stress, 5)
        XCTAssertEqual(restored.dayEnergy, 3)
        XCTAssertEqual(restored.wakeTime, wokeAt)
        let owner = try XCTUnwrap(try target.fetch(UserProfile.fetchRequest()).first)
        XCTAssertEqual(owner.sleepNeedHours, 8.5)
        XCTAssertEqual(owner.yellowMode, "suggest")
    }
}
