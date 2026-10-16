import Foundation
import UIKit
import Combine

enum PendingMealStatus {
    case loading
    case done(NutritionAnalysis)
    case failed(String)
}

private struct PendingMealSnapshot: Codable {
    let id: UUID
    let note: String?
    let plateDiameter: Double?
    let createdAt: Date
    let state: String
    let analysis: NutritionAnalysis?
    let errorMessage: String?
    let hasImage: Bool?
    let eatenAt: Date?
}

final class PendingMealItem: ObservableObject, Identifiable {
    let id: UUID
    let image: UIImage?
    let note: String?
    let plateDiameter: Double?
    let createdAt: Date
    let eatenAt: Date
    @Published var status: PendingMealStatus = .loading

    init(image: UIImage?, note: String?, plateDiameter: Double?, eatenAt: Date) {
        self.id = UUID()
        self.image = image
        self.note = note
        self.plateDiameter = plateDiameter
        self.createdAt = Date()
        self.eatenAt = eatenAt
    }

    init(id: UUID, image: UIImage?, note: String?, plateDiameter: Double?, createdAt: Date, eatenAt: Date,
         status: PendingMealStatus) {
        self.id = id
        self.image = image
        self.note = note
        self.plateDiameter = plateDiameter
        self.createdAt = createdAt
        self.eatenAt = eatenAt
        self.status = status
    }
}

final class PendingMealStore: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    private(set) var items: [PendingMealItem] = [] {
        willSet { objectWillChange.send() }
    }

    static let shared = PendingMealStore()

    nonisolated static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PendingMeals", isDirectory: true)
    }

    private let directoryURL: URL

    init(directory: URL = PendingMealStore.defaultDirectory) {
        directoryURL = directory
        LocalStorage.prepareDirectory(directoryURL)
        items = loadSnapshots().sorted { $0.createdAt > $1.createdAt }
        sweepOrphans()
        for item in items {
            if case .loading = item.status {
                runAnalysis(for: item)
            }
        }
    }

    func submit(image: UIImage?, note: String?, plateDiameter: Double?, eatenAt: Date = Date()) {
        let item = PendingMealItem(image: image, note: note, plateDiameter: plateDiameter, eatenAt: eatenAt)
        items.insert(item, at: 0)
        objectWillChange.send()
        persistSnapshot(item)
        if let image, let jpeg = GeminiService.analysisJPEG(from: image) {
            try? jpeg.write(to: imageURL(for: item.id), options: .atomic)
        }
        runAnalysis(for: item)
    }

    func retry(_ item: PendingMealItem) {
        item.status = .loading
        persistSnapshot(item)
        runAnalysis(for: item)
    }

    func remove(_ item: PendingMealItem) {
        let kind = ModelJobKind.mealAnalysis(pendingItemID: item.id)
        for job in ModelJobStore.shared.jobs where job.kind == kind {
            BackgroundModelClient.shared.cancel(jobID: job.id)
            ModelJobStore.shared.remove(id: job.id)
        }
        items.removeAll { $0.id == item.id }
        objectWillChange.send()
        deleteFiles(for: item.id)
    }

    func applyAnalysisStatus(itemID: UUID, status: PendingMealStatus) {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        item.status = status
        persistSnapshot(item)
    }

    private func runAnalysis(for item: PendingMealItem) {
        let kind = ModelJobKind.mealAnalysis(pendingItemID: item.id)
        guard !ModelJobStore.shared.isPending(kind) else { return }
        do {
            let body: Data
            if item.image == nil {
                body = try GeminiService.descriptionRequestBody(description: item.note ?? "")
            } else if let jpeg = try? Data(contentsOf: imageURL(for: item.id)) {
                body = try GeminiService.analysisRequestBody(jpegData: jpeg, note: item.note,
                                                             plateDiameterCm: item.plateDiameter)
            } else {
                applyAnalysisStatus(itemID: item.id, status: .failed(GeminiError.invalidImage.localizedDescription))
                return
            }
            try BackgroundModelClient.shared.enqueue(kind, body: body)
        } catch {
            applyAnalysisStatus(itemID: item.id, status: .failed(error.localizedDescription))
        }
    }

    private func imageURL(for id: UUID) -> URL {
        directoryURL.appendingPathComponent("\(id.uuidString).jpg")
    }

    private func jsonURL(for id: UUID) -> URL {
        directoryURL.appendingPathComponent("\(id.uuidString).json")
    }

    private func persistSnapshot(_ item: PendingMealItem) {
        let state: String
        var analysis: NutritionAnalysis?
        var errorMessage: String?
        switch item.status {
        case .loading:
            state = "loading"
        case .done(let result):
            state = "done"
            analysis = result
        case .failed(let message):
            state = "failed"
            errorMessage = message
        }
        let snapshot = PendingMealSnapshot(
            id: item.id,
            note: item.note,
            plateDiameter: item.plateDiameter,
            createdAt: item.createdAt,
            state: state,
            analysis: analysis,
            errorMessage: errorMessage,
            hasImage: item.image != nil,
            eatenAt: item.eatenAt
        )
        guard let snapshotData = try? JSONEncoder().encode(snapshot) else { return }
        try? snapshotData.write(to: jsonURL(for: item.id))
    }

    private func deleteFiles(for id: UUID) {
        try? FileManager.default.removeItem(at: imageURL(for: id))
        try? FileManager.default.removeItem(at: jsonURL(for: id))
    }

    private func sweepOrphans() {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else {
            return
        }
        let validStems = Set(items.map { $0.id.uuidString })
        for url in contents where url.pathExtension == "jpg" || url.pathExtension == "json" {
            if !validStems.contains(url.deletingPathExtension().lastPathComponent) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func loadSnapshots() -> [PendingMealItem] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else {
            return []
        }
        var result: [PendingMealItem] = []
        for url in contents where url.pathExtension == "json" {
            guard let uuid = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { continue }
            guard let jsonData = try? Data(contentsOf: url),
                  let snapshot = try? JSONDecoder().decode(PendingMealSnapshot.self, from: jsonData) else {
                deleteFiles(for: uuid)
                continue
            }
            let image = (try? Data(contentsOf: imageURL(for: uuid))).flatMap(UIImage.init(data:))
            if image == nil && snapshot.hasImage != false {
                deleteFiles(for: uuid)
                continue
            }
            let status: PendingMealStatus
            switch snapshot.state {
            case "done":
                guard let analysis = snapshot.analysis else {
                    deleteFiles(for: uuid)
                    continue
                }
                status = .done(analysis)
            case "failed":
                status = .failed(snapshot.errorMessage ?? "")
            default:
                status = .loading
            }
            let item = PendingMealItem(
                id: snapshot.id,
                image: image,
                note: snapshot.note,
                plateDiameter: snapshot.plateDiameter,
                createdAt: snapshot.createdAt,
                eatenAt: snapshot.eatenAt ?? snapshot.createdAt,
                status: status
            )
            result.append(item)
        }
        return result
    }
}
