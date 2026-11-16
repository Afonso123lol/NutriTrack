import Foundation
import Combine

final class ModelJobStore: ObservableObject {
    static let shared = ModelJobStore(directory: ModelJobStore.defaultDirectory)

    nonisolated static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ModelJobs", isDirectory: true)
    }

    @Published private(set) var jobs: [ModelJob] = []
    @Published private(set) var failures: [ModelJobKind: String] = [:]

    private let directory: URL

    init(directory: URL) {
        self.directory = directory
        LocalStorage.prepareDirectory(directory)
        jobs = loadJobs().sorted { $0.createdAt < $1.createdAt }
    }

    func add(_ job: ModelJob, body: Data) throws {
        try body.write(to: bodyURL(for: job.id), options: .atomic)
        try JSONEncoder().encode(job).write(to: jsonURL(for: job.id), options: .atomic)
        jobs.append(job)
        failures[job.kind] = nil
    }

    func update(_ job: ModelJob) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        jobs[index] = job
        try? JSONEncoder().encode(job).write(to: jsonURL(for: job.id), options: .atomic)
    }

    func remove(id: UUID) {
        jobs.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: bodyURL(for: id))
        try? FileManager.default.removeItem(at: jsonURL(for: id))
    }

    func job(id: UUID) -> ModelJob? {
        jobs.first { $0.id == id }
    }

    func isPending(_ kind: ModelJobKind) -> Bool {
        jobs.contains { $0.kind == kind }
    }

    func recordFailure(_ message: String, for kind: ModelJobKind) {
        failures[kind] = message
    }

    func bodyURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).body")
    }

    private func jsonURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private func loadJobs() -> [ModelJob] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return contents
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let job = try? JSONDecoder().decode(ModelJob.self, from: data),
                      FileManager.default.fileExists(atPath: bodyURL(for: job.id).path) else {
                    try? FileManager.default.removeItem(at: url)
                    return nil
                }
                if job.kind.isObsolete {
                    try? FileManager.default.removeItem(at: url)
                    try? FileManager.default.removeItem(at: bodyURL(for: job.id))
                    return nil
                }
                return job
            }
    }
}
