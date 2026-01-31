import Foundation
import Combine

// MARK: - Service Priority Levels
enum ServicePriority: Int, CaseIterable {
    case critical = 0    // UserService, TelemetryService
    case high = 1        // InvestmentService, DashboardService
    case medium = 2      // NotificationService, DocumentService
    case low = 3         // WatchlistService, TraderDataService
    case background = 4  // TestModeService, TraderService
}

// MARK: - Service Lifecycle Coordinator
/// Coordinates the startup, shutdown, and lifecycle management of application services
/// following priority-based orchestration and dependency resolution.
@MainActor
final class ServiceLifecycleCoordinator: ObservableObject {
    @Published var isInitialized = false
    @Published var criticalServicesReady = false
    @Published var allServicesReady = false

    private var services: AppServices
    private var serviceStates: [String: ServiceState] = [:]
    private var startupQueue: [ServiceStartupItem] = []
    private var cancellables = Set<AnyCancellable>()

    init(services: AppServices) {
        self.services = services
        setupServicePriorities()
    }

    // MARK: - Service State Management

    private enum ServiceState: Equatable {
        case notStarted
        case starting
        case running
        case stopped
        case failed(Error)

        static func == (lhs: ServiceState, rhs: ServiceState) -> Bool {
            switch (lhs, rhs) {
            case (.notStarted, .notStarted), (.starting, .starting), (.running, .running), (.stopped, .stopped):
                return true
            case (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }

    private struct ServiceStartupItem {
        let name: String
        let priority: ServicePriority
        let service: ServiceLifecycle
        let dependencies: [String]
    }

    // MARK: - Service Priority Configuration

    private func setupServicePriorities() {
        // Critical services - start immediately
        if let userService = services.userService as? ServiceLifecycle {
            addService("UserService", priority: .critical, service: userService, dependencies: [])
        }
        if let telemetryService = services.telemetryService as? ServiceLifecycle {
            addService("TelemetryService", priority: .critical, service: telemetryService, dependencies: [])
        }

        // High priority services - start after critical
        if let investmentService = services.investmentService as? ServiceLifecycle {
            addService("InvestmentService", priority: .high, service: investmentService, dependencies: ["UserService"])
        }
        if let dashboardService = services.dashboardService as? ServiceLifecycle {
            addService("DashboardService", priority: .high, service: dashboardService, dependencies: ["UserService"])
        }

        // Medium priority services - start after high
        if let notificationService = services.notificationService as? ServiceLifecycle {
            addService("NotificationService", priority: .medium, service: notificationService, dependencies: ["UserService"])
        }
        // DocumentService always conforms to ServiceLifecycle (protocol conformance)
        let documentService = services.documentService as ServiceLifecycle
        addService("DocumentService", priority: .medium, service: documentService, dependencies: ["UserService"])

        // Low priority services - start after medium
        if let watchlistService = services.watchlistService as? ServiceLifecycle {
            addService("WatchlistService", priority: .low, service: watchlistService, dependencies: ["UserService"])
        }
        if let traderDataService = services.traderDataService as? ServiceLifecycle {
            addService("TraderDataService", priority: .low, service: traderDataService, dependencies: ["UserService"])
        }

        // Background services - start last
        if let testModeService = services.testModeService as? ServiceLifecycle {
            addService("TestModeService", priority: .background, service: testModeService, dependencies: [])
        }
        if let traderService = services.traderService as? ServiceLifecycle {
            addService("TraderService", priority: .background, service: traderService, dependencies: ["UserService"])
        }
    }

    private func addService(_ name: String, priority: ServicePriority, service: ServiceLifecycle, dependencies: [String]) {
        let item = ServiceStartupItem(
            name: name,
            priority: priority,
            service: service,
            dependencies: dependencies
        )
        startupQueue.append(item)
        serviceStates[name] = .notStarted
    }

    // MARK: - Optimized Service Startup

    func startServices() async {
        guard !isInitialized else { return }

        print("🚀 Starting services with optimized lifecycle...")

        // Sort services by priority
        startupQueue.sort { $0.priority.rawValue < $1.priority.rawValue }

        // Start services in batches based on priority
        await startServicesByPriority()

        isInitialized = true
        print("✅ All services started successfully")
    }

    private func startServicesByPriority() async {
        let priorityGroups = Dictionary(grouping: startupQueue) { $0.priority }

        for priority in ServicePriority.allCases {
            guard let services = priorityGroups[priority] else { continue }

            print("🔄 Starting \(priority) priority services...")

            // Start services in parallel within the same priority group
            await withTaskGroup(of: Void.self) { group in
                for serviceItem in services {
                    group.addTask {
                        await self.startService(serviceItem)
                    }
                }
            }

            // Update critical services ready flag
            if priority == .critical {
                criticalServicesReady = true
            }

            // Only add delay for background services, not critical/high priority
            if priority == .background {
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            }
        }

        allServicesReady = true
    }

    private func startService(_ item: ServiceStartupItem) async {
        // Check if dependencies are ready with reduced polling
        for dependency in item.dependencies {
            while serviceStates[dependency] != .running {
                try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds (reduced from 0.05)
            }
        }

        serviceStates[item.name] = .starting

        // Start the service (no throwing operations)
        item.service.start()
        serviceStates[item.name] = .running
        print("✅ \(item.name) started successfully")
    }

    // MARK: - Optimized Service Shutdown

    func stopServices() async {
        print("🛑 Stopping services...")

        // Stop services in reverse priority order
        for priority in ServicePriority.allCases.reversed() {
            let services = startupQueue.filter { $0.priority == priority }

            for serviceItem in services {
                if serviceStates[serviceItem.name] == .running {
                    serviceItem.service.stop()
                    serviceStates[serviceItem.name] = .stopped
                    print("🛑 \(serviceItem.name) stopped")
                }
            }
        }

        isInitialized = false
        criticalServicesReady = false
        allServicesReady = false
    }

    // MARK: - Lazy Service Loading

    func startServiceOnDemand(_ serviceName: String) async {
        guard let serviceItem = startupQueue.first(where: { $0.name == serviceName }) else {
            print("⚠️ Service \(serviceName) not found")
            return
        }

        guard serviceStates[serviceName] == .notStarted else {
            print("ℹ️ Service \(serviceName) already started")
            return
        }

        await startService(serviceItem)
    }

    // MARK: - Service Health Monitoring

    func getServiceStatus() -> [String: String] {
        var status: [String: String] = [:]

        for (name, state) in serviceStates {
            switch state {
            case .notStarted:
                status[name] = "Not Started"
            case .starting:
                status[name] = "Starting"
            case .running:
                status[name] = "Running"
            case .stopped:
                status[name] = "Stopped"
            case .failed(let error):
                status[name] = "Failed: \(error.localizedDescription)"
            }
        }

        return status
    }

    // MARK: - Memory Optimization

    func optimizeMemoryUsage() {
        // Clear caches for non-critical services when memory pressure is high
        if let watchlistService = services.watchlistService as? ServiceLifecycle {
            watchlistService.reset()
        }

        if let traderDataService = services.traderDataService as? ServiceLifecycle {
            traderDataService.reset()
        }

        print("🧹 Memory optimization completed")
    }
}

// MARK: - Service Lifecycle Extensions

extension ServiceLifecycle {
    func start() {
        // Default implementation - services can override
        print("🔄 Starting \(String(describing: type(of: self)))")
    }

    func stop() {
        // Default implementation - services can override
        print("🛑 Stopping \(String(describing: type(of: self)))")
    }

    func reset() {
        // Default implementation - services can override
        print("🔄 Resetting \(String(describing: type(of: self)))")
    }
}
