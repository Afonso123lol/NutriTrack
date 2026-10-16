import Foundation

nonisolated struct SyncConfig: Equatable, Sendable {
    let baseURL: URL
    let token: String

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    init?(info: [String: Any], usesTestStore: Bool = false) {
        guard let rawURL = info["SYNC_BASE_URL"] as? String,
              let token = info[usesTestStore ? "SYNC_TEST_TOKEN" : "SYNC_TOKEN"] as? String,
              !token.isEmpty,
              let url = URL(string: rawURL),
              url.scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        self.baseURL = url
        self.token = token
    }

    static func current(bundle: Bundle = .main,
                        environment: [String: String] = ProcessInfo.processInfo.environment,
                        usesTestStore: Bool = SyncConfig.isSimulator) -> SyncConfig? {
        guard environment["XCTestConfigurationFilePath"] == nil else { return nil }
        return SyncConfig(info: bundle.infoDictionary ?? [:], usesTestStore: usesTestStore)
    }

    func request(path: String, method: String, contentType: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
