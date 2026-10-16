import XCTest
import CoreData
@testable import NutriTrack

final class ModelMigrationTests: XCTestCase {

    private func compiledModel(named name: String) throws -> NSManagedObjectModel {
        let momd = try XCTUnwrap(Bundle.main.url(forResource: "NutriTrack", withExtension: "momd"))
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: momd.appendingPathComponent("\(name).mom")))
    }

    private func attributes(of entity: String) throws -> [String: NSAttributeDescription] {
        let model = Persistence(inMemory: true).container.managedObjectModel
        return try XCTUnwrap(model.entitiesByName[entity]).attributesByName
    }

    func testCurrentModelHasOptionalCoachFields() throws {
        let attributes = try attributes(of: "DailyEvaluation")
        XCTAssertEqual(attributes["coachText"]?.attributeType, .stringAttributeType)
        XCTAssertEqual(attributes["coachText"]?.isOptional, true)
        XCTAssertEqual(attributes["coachGeneratedAt"]?.attributeType, .dateAttributeType)
        XCTAssertEqual(attributes["coachGeneratedAt"]?.isOptional, true)
    }

    func testCurrentModelHasVersionThreeFields() throws {
        let food = try attributes(of: "FoodEntry")
        XCTAssertEqual(food["alcoholG"]?.attributeType, .doubleAttributeType)
        XCTAssertEqual(food["thumbnailData"]?.attributeType, .binaryDataAttributeType)
        XCTAssertEqual(food["wasEdited"]?.attributeType, .booleanAttributeType)
        XCTAssertEqual(food["sourceEntryID"]?.attributeType, .UUIDAttributeType)
        let evaluation = try attributes(of: "DailyEvaluation")
        XCTAssertEqual(evaluation["closedAt"]?.attributeType, .dateAttributeType)
        XCTAssertEqual(evaluation["isLogComplete"]?.attributeType, .booleanAttributeType)
        let template = try attributes(of: "SupplementTemplate")
        for name in ["sodiumMg", "fiberG", "sugarG"] {
            XCTAssertEqual(template[name]?.attributeType, .doubleAttributeType, name)
        }
    }

    func testEveryEntityIsIndexedById() {
        let model = Persistence(inMemory: true).container.managedObjectModel
        for entity in model.entities {
            let indexed = entity.indexes.flatMap(\.elements).compactMap(\.propertyName)
            XCTAssertTrue(indexed.contains("id"), entity.name ?? "")
        }
    }

    private func assertStoreMigrates(from version: String) throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString).sqlite")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
        }

        let oldModel = try compiledModel(named: version)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
        let store = try coordinator.addPersistentStore(type: .sqlite, at: storeURL)
        let context = NSManagedObjectContext(.mainQueue)
        context.persistentStoreCoordinator = coordinator
        let id = UUID()
        let evaluation = NSEntityDescription.insertNewObject(forEntityName: "DailyEvaluation", into: context)
        evaluation.setValue(id, forKey: "id")
        evaluation.setValue("Slept well", forKey: "sleepText")
        let meal = NSEntityDescription.insertNewObject(forEntityName: "FoodEntry", into: context)
        meal.setValue(UUID(), forKey: "id")
        meal.setValue("Eggs", forKey: "dishName")
        meal.setValue(300.0, forKey: "calories")
        try context.save()
        try coordinator.remove(store)

        let container = NSPersistentContainer(name: "NutriTrack")
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        XCTAssertNil(loadError)

        let evaluations = try container.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "DailyEvaluation"))
        XCTAssertEqual(evaluations.count, 1)
        XCTAssertEqual(evaluations.first?.value(forKey: "id") as? UUID, id)
        XCTAssertEqual(evaluations.first?.value(forKey: "sleepText") as? String, "Slept well")
        XCTAssertNil(evaluations.first?.value(forKey: "coachText"))
        XCTAssertNil(evaluations.first?.value(forKey: "closedAt"))
        XCTAssertEqual(evaluations.first?.value(forKey: "isLogComplete") as? Bool, false)

        let meals = try container.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "FoodEntry"))
        XCTAssertEqual(meals.count, 1)
        XCTAssertEqual(meals.first?.value(forKey: "dishName") as? String, "Eggs")
        XCTAssertEqual(meals.first?.value(forKey: "calories") as? Double, 300)
        XCTAssertEqual(meals.first?.value(forKey: "alcoholG") as? Double, 0)
        XCTAssertEqual(meals.first?.value(forKey: "wasEdited") as? Bool, false)
        XCTAssertNil(meals.first?.value(forKey: "sourceEntryID"))
        XCTAssertNil(meals.first?.value(forKey: "thumbnailData"))
    }

    func testVersionOneStoreOpensWithCurrentModelAndKeepsData() throws {
        try assertStoreMigrates(from: "NutriTrack")
    }

    func testVersionTwoStoreOpensWithCurrentModelAndKeepsData() throws {
        try assertStoreMigrates(from: "NutriTrack 2")
    }

    func testCurrentModelHasVersionFourEntities() throws {
        let model = Persistence(inMemory: true).container.managedObjectModel
        for name in ["TargetSnapshot", "TrainingProfile", "TrainingWeek", "PlannedSession", "TrainingSession", "StrengthSet"] {
            let entity = try XCTUnwrap(model.entitiesByName[name], name)
            XCTAssertEqual(entity.attributesByName["id"]?.attributeType, .UUIDAttributeType, name)
        }
        let profile = try attributes(of: "UserProfile")
        XCTAssertEqual(profile["weeklyRatePercent"]?.attributeType, .doubleAttributeType)
        XCTAssertEqual(profile["activityFactor"]?.attributeType, .doubleAttributeType)
        XCTAssertEqual(profile["goalChangedAt"]?.attributeType, .dateAttributeType)
        let checkIn = try attributes(of: "DailyCheckIn")
        XCTAssertEqual(checkIn["isSick"]?.attributeType, .booleanAttributeType)
        XCTAssertEqual(checkIn["hasPain"]?.attributeType, .booleanAttributeType)
        XCTAssertEqual(SyncEntities.all.count, 13)
        for name in SyncEntities.all { XCTAssertNotNil(model.entitiesByName[name], name) }
    }

    func testVersionThreeStoreOpensWithCurrentModelAndKeepsData() throws {
        try assertStoreMigrates(from: "NutriTrack 3")
    }

    func testVersionFourStoreOpensWithCurrentModelAndKeepsData() throws {
        try assertStoreMigrates(from: "NutriTrack 4")
    }

    func testCurrentModelHasOptionalBirthDate() throws {
        let birthDate = try XCTUnwrap(attributes(of: "UserProfile")["birthDate"])
        XCTAssertEqual(birthDate.attributeType, .dateAttributeType)
        XCTAssertTrue(birthDate.isOptional)
    }

    func testAgeFollowsTheBirthDate() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let profile = UserProfile(context: ctx)
        profile.age = 30
        XCTAssertFalse(profile.refreshAge())
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        profile.setBirthDate(now.addingTimeInterval(-22.5 * 365.25 * 86400), now: now)
        XCTAssertEqual(profile.age, 22)
        XCTAssertFalse(profile.refreshAge(now: now))
        XCTAssertTrue(profile.refreshAge(now: now.addingTimeInterval(365.25 * 86400)))
        XCTAssertEqual(profile.age, 23)
    }

    func testCurrentModelHasVersionSixFields() throws {
        let checkIn = try attributes(of: "DailyCheckIn")
        for name in ["soreness", "stress", "dayEnergy"] {
            XCTAssertEqual(checkIn[name]?.attributeType, .integer16AttributeType, name)
            XCTAssertEqual(checkIn[name]?.defaultValue as? Int, 0, name)
        }
        XCTAssertEqual(checkIn["suggestionChoice"]?.attributeType, .stringAttributeType)
        XCTAssertEqual(checkIn["suggestionChoice"]?.isOptional, true)
        let profile = try attributes(of: "UserProfile")
        XCTAssertEqual(profile["sleepNeedHours"]?.defaultValue as? Double, 8)
        XCTAssertEqual(profile["yellowMode"]?.defaultValue as? String, "suggest")
        XCTAssertEqual(profile["calibrationStartedAt"]?.attributeType, .dateAttributeType)
        XCTAssertEqual(try attributes(of: "TrainingWeek")["lightWeekChoice"]?.attributeType, .stringAttributeType)
        let session = try attributes(of: "TrainingSession")
        XCTAssertEqual(session["weightAfterKg"]?.attributeType, .doubleAttributeType)
        XCTAssertEqual(session["fluidsL"]?.attributeType, .doubleAttributeType)
    }

    func testVersionFiveStoreOpensWithCurrentModelAndKeepsData() throws {
        try assertStoreMigrates(from: "NutriTrack 5")
    }

    func testVersionFiveCheckInAndProfileGetTheNewDefaults() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString).sqlite")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
        }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try compiledModel(named: "NutriTrack 5"))
        let store = try coordinator.addPersistentStore(type: .sqlite, at: storeURL)
        let context = NSManagedObjectContext(.mainQueue)
        context.persistentStoreCoordinator = coordinator
        let wokeAt = Date(timeIntervalSince1970: 1_790_000_000)
        let checkIn = NSEntityDescription.insertNewObject(forEntityName: "DailyCheckIn", into: context)
        checkIn.setValue(UUID(), forKey: "id")
        checkIn.setValue(Int16(4), forKey: "energyLevel")
        checkIn.setValue(7.5, forKey: "sleepHours")
        checkIn.setValue(wokeAt, forKey: "wakeTime")
        let profile = NSEntityDescription.insertNewObject(forEntityName: "UserProfile", into: context)
        profile.setValue(UUID(), forKey: "id")
        profile.setValue("Afonso", forKey: "name")
        try context.save()
        try coordinator.remove(store)

        let container = NSPersistentContainer(name: "NutriTrack")
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        XCTAssertNil(loadError)

        let checkIns = try container.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "DailyCheckIn"))
        let migrated = try XCTUnwrap(checkIns.first)
        XCTAssertEqual(migrated.value(forKey: "energyLevel") as? Int, 4)
        XCTAssertEqual(migrated.value(forKey: "sleepHours") as? Double, 7.5)
        XCTAssertEqual(migrated.value(forKey: "wakeTime") as? Date, wokeAt)
        XCTAssertEqual(migrated.value(forKey: "soreness") as? Int, 0)
        XCTAssertEqual(migrated.value(forKey: "stress") as? Int, 0)
        XCTAssertEqual(migrated.value(forKey: "dayEnergy") as? Int, 0)
        XCTAssertNil(migrated.value(forKey: "suggestionChoice"))

        let profiles = try container.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "UserProfile"))
        let owner = try XCTUnwrap(profiles.first)
        XCTAssertEqual(owner.value(forKey: "name") as? String, "Afonso")
        XCTAssertEqual(owner.value(forKey: "sleepNeedHours") as? Double, 8)
        XCTAssertEqual(owner.value(forKey: "yellowMode") as? String, "suggest")
        XCTAssertNil(owner.value(forKey: "calibrationStartedAt"))
    }
}
