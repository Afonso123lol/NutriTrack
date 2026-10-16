import XCTest
@testable import NutriTrack

final class SyncConfigTests: XCTestCase {

    private let valid: [String: Any] = ["SYNC_BASE_URL": "https://vps.example.ts.net", "SYNC_TOKEN": "secret-token"]

    func testValidInfoGivesConfig() {
        let config = SyncConfig(info: valid)
        XCTAssertEqual(config?.baseURL.absoluteString, "https://vps.example.ts.net")
        XCTAssertEqual(config?.token, "secret-token")
    }

    func testMissingOrEmptyValuesGiveNil() {
        XCTAssertNil(SyncConfig(info: [:]))
        XCTAssertNil(SyncConfig(info: ["SYNC_BASE_URL": "", "SYNC_TOKEN": ""]))
        XCTAssertNil(SyncConfig(info: ["SYNC_BASE_URL": "https://vps.example.ts.net", "SYNC_TOKEN": ""]))
        XCTAssertNil(SyncConfig(info: ["SYNC_BASE_URL": "", "SYNC_TOKEN": "x"]))
    }

    func testSimulatorBuildsUseTheTestTokenOrNothing() {
        var info = valid
        XCTAssertNil(SyncConfig(info: info, usesTestStore: true))
        info["SYNC_TEST_TOKEN"] = ""
        XCTAssertNil(SyncConfig(info: info, usesTestStore: true))
        info["SYNC_TEST_TOKEN"] = "test-token"
        XCTAssertEqual(SyncConfig(info: info, usesTestStore: true)?.token, "test-token")
        XCTAssertEqual(SyncConfig(info: info, usesTestStore: false)?.token, "secret-token")
    }

    func testPlainHTTPIsRefused() {
        XCTAssertNil(SyncConfig(info: ["SYNC_BASE_URL": "http://vps.example.ts.net", "SYNC_TOKEN": "x"]))
    }

    func testSyncIsOffWhileRunningTests() {
        XCTAssertNil(SyncConfig.current())
    }

    func testOutsideTestsTheBundleDecides() {
        XCTAssertEqual(SyncConfig.current(environment: [:], usesTestStore: false),
                       SyncConfig(info: Bundle.main.infoDictionary ?? [:]))
    }

    func testRequestCarriesBearerTokenAndPath() throws {
        let request = try XCTUnwrap(SyncConfig(info: valid)).request(path: "v1/photos/ABC", method: "PUT", contentType: "image/jpeg")
        XCTAssertEqual(request.url?.absoluteString, "https://vps.example.ts.net/v1/photos/ABC")
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "image/jpeg")
    }
}
