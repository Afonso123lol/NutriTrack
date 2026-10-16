import XCTest
@testable import NutriTrack

final class SyncEngineTests: XCTestCase {

    func testForegroundLaunchIsLoggedOnce() {
        XCTAssertEqual(SyncEngine.launchEvent(inBackground: false, logged: []), "app.launch")
        XCTAssertNil(SyncEngine.launchEvent(inBackground: false, logged: ["app.launch"]))
    }

    func testBackgroundWakeAfterForegroundLaunchIsNotALaunch() {
        XCTAssertNil(SyncEngine.launchEvent(inBackground: true, logged: ["app.launch"]))
    }

    func testBackgroundLaunchIsLoggedOnce() {
        XCTAssertEqual(SyncEngine.launchEvent(inBackground: true, logged: []), "app.backgroundLaunch")
        XCTAssertNil(SyncEngine.launchEvent(inBackground: true, logged: ["app.backgroundLaunch"]))
    }

    func testOpeningTheAppAfterABackgroundLaunchIsStillALaunch() {
        XCTAssertEqual(SyncEngine.launchEvent(inBackground: false, logged: ["app.backgroundLaunch"]), "app.launch")
    }
}
