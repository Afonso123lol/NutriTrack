import XCTest
@testable import NutriTrack

final class LocalStorageTests: XCTestCase {

    func testPreparedDirectoryExistsAndIsExcludedFromBackup() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("storage-\(UUID().uuidString)", isDirectory: true)
        LocalStorage.prepareDirectory(dir)
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(try dir.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }
}
