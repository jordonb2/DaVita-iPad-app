import Foundation
import CoreData

struct CheckInSyncItem: Codable, Equatable {
    let id: UUID
    let personURI: String
    let createdAt: Date
    let data: Payload

    struct Payload: Codable, Equatable {
        let painLevel: Int16?
        let energyBucket: Int16?
        let moodBucket: Int16?
        let symptoms: String?
        let concerns: String?
        let teamNote: String?
    }

    init(personID: NSManagedObjectID, createdAt: Date, data: PersonCheckInData) {
        self.id = UUID()
        self.personURI = personID.uriRepresentation().absoluteString
        self.createdAt = createdAt
        self.data = Payload(
            painLevel: data.painLevel,
            energyBucket: data.energyBucket?.rawValue,
            moodBucket: data.moodBucket?.rawValue,
            symptoms: data.symptoms,
            concerns: data.concerns,
            teamNote: data.teamNote
        )
    }
}

/// Thread-safe, file-backed queue of pending check-ins to sync when connectivity returns.
final class CheckInSyncQueue {
    private let queue = DispatchQueue(label: "com.davita.checkin.sync.queue", qos: .utility)
    private let storeURL: URL

    init(storeURL: URL) {
        self.storeURL = storeURL
    }

    func enqueue(personID: NSManagedObjectID, createdAt: Date, data: PersonCheckInData) {
        queue.sync {
            var items = load()
            items.append(CheckInSyncItem(personID: personID, createdAt: createdAt, data: data))
            persist(items)
        }
    }

    func pending() -> [CheckInSyncItem] {
        queue.sync { load() }
    }

    func remove(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        queue.sync {
            let items = load().filter { !idSet.contains($0.id) }
            persist(items)
        }
    }

    // MARK: - Persistence
    private func load() -> [CheckInSyncItem] {
        guard let data = try? Data(contentsOf: storeURL) else { return [] }
        return (try? JSONDecoder().decode([CheckInSyncItem].self, from: data)) ?? []
    }

    private func persist(_ items: [CheckInSyncItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            AppLog.persistence.error("CheckInSyncQueue persist error: \(error, privacy: .private)")
        }
    }
}
