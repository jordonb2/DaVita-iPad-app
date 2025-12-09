import Foundation
import Network
import CoreData

protocol CheckInSyncHandling: AnyObject {
    func enqueueForSync(personID: NSManagedObjectID, createdAt: Date, data: PersonCheckInData)
}

protocol CheckInSyncTransporting {
    func upload(_ items: [CheckInSyncItem], completion: @escaping (Bool) -> Void)
}

/// Simple transport that can be swapped for a real API client. Currently just simulates success.
final class NoopCheckInSyncTransport: CheckInSyncTransporting {
    func upload(_ items: [CheckInSyncItem], completion: @escaping (Bool) -> Void) {
        // In a real implementation, call your backend here.
        completion(true)
    }
}

/// Monitors connectivity and pushes pending check-ins when the network is available.
final class CheckInSyncManager: CheckInSyncHandling {
    private let queue: CheckInSyncQueue
    private let transport: CheckInSyncTransporting
    private let monitor: NWPathMonitor
    private let workQueue = DispatchQueue(label: "com.davita.checkin.sync.manager", qos: .utility)
    private var isOnline: Bool = false

    init(queue: CheckInSyncQueue,
         transport: CheckInSyncTransporting = NoopCheckInSyncTransport(),
         monitor: NWPathMonitor = NWPathMonitor()) {
        self.queue = queue
        self.transport = transport
        self.monitor = monitor
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    func enqueueForSync(personID: NSManagedObjectID, createdAt: Date, data: PersonCheckInData) {
        queue.enqueue(personID: personID, createdAt: createdAt, data: data)
        attemptSyncIfOnline()
    }

    // MARK: - Connectivity + sync
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.isOnline = (path.status == .satisfied)
            if self.isOnline {
                self.attemptSyncIfOnline()
            }
        }
        monitor.start(queue: workQueue)
    }

    private func attemptSyncIfOnline() {
        workQueue.async { [weak self] in
            guard let self else { return }
            guard self.isOnline else { return }

            let items = self.queue.pending()
            guard !items.isEmpty else { return }

            self.transport.upload(items) { success in
                if success {
                    self.queue.remove(ids: items.map { $0.id })
                }
            }
        }
    }
}
