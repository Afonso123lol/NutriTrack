import XCTest
import CoreData
@testable import NutriTrack

@MainActor
final class SyncBackfillTests: XCTestCase {

    func testBackfillQueuesEveryObjectOnce() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let queue = SyncQueue(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("backfill-\(UUID().uuidString)", isDirectory: true))

        for _ in 0..<2 {
            let weight = WeightEntry(context: ctx)
            weight.id = UUID()
        }
        let withPhoto = FoodEntry(context: ctx)
        let photoID = UUID()
        withPhoto.id = photoID
        withPhoto.photoData = Data([0xFF, 0xD8, 0xFF])
        let withoutPhoto = FoodEntry(context: ctx)
        withoutPhoto.id = UUID()
        let profile = UserProfile(context: ctx)
        profile.id = UUID()
        let withoutID = WeightEntry(context: ctx)
        withoutID.weightKg = 70
        try ctx.save()

        XCTAssertTrue(SyncBackfill.runIfNeeded(context: ctx, queue: queue))
        XCTAssertEqual(queue.state.records.count, 5)
        XCTAssertTrue(queue.state.records.values.allSatisfy { !$0.deleted })
        XCTAssertEqual(queue.state.photos, [photoID])
        XCTAssertTrue(queue.state.backfillDone)

        let before = queue.state
        XCTAssertFalse(SyncBackfill.runIfNeeded(context: ctx, queue: queue))
        XCTAssertEqual(queue.state, before)
    }
}
