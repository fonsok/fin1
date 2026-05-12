import Foundation
import Network
import Combine

// MARK: - Notifications

extension Notification.Name {
    /// Posted exactly when connectivity transitions from unreachable to reachable (not on cold start if already online).
    static let fin1NetworkReachableAgain = Notification.Name("fin1.network.reachableAgain")
}

// MARK: - Network Monitor

/// Monitors network connectivity status
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    /// Suppress false “reachable again” during first path snapshot.
    private var hasSeenPathUpdate = false
    private var lastPathSatisfied = false

    private init() {
        startMonitoring()
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                let satisfied = path.status == .satisfied

                if self.hasSeenPathUpdate,
                   self.lastPathSatisfied == false,
                   satisfied == true {
                    NotificationCenter.default.post(name: .fin1NetworkReachableAgain, object: nil)
                }
                self.hasSeenPathUpdate = true
                self.lastPathSatisfied = satisfied
                self.isConnected = satisfied

                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                } else {
                    self.connectionType = .unknown
                }

                #if DEBUG
                print("🌐 NetworkMonitor: Connection status changed - Connected: \(self.isConnected), Type: \(self.connectionType)")
                #endif
            }
        }

        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }
}
