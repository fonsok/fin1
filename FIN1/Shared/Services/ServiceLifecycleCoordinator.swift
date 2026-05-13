import Combine
import Foundation

/// Dependency ordering / wait-timeout failures during coordinated startup.
enum ServiceLifecycleCoordinatorError: LocalizedError, Equatable {
    case dependencyTimeout(waitingService: String, dependency: String, timeoutSeconds: Double)
    case blockedByFailedDependency(waitingService: String, dependency: String)
    /// Remaining tiers not started because a critical service failed.
    case skippedAfterCriticalFailure(waitingService: String)

    var errorDescription: String? {
        switch self {
        case .dependencyTimeout(let waiting, let dep, let secs):
            return "Service startup: timeout after \(secs)s waiting for dependency '\(dep)' (service: '\(waiting)')."
        case .blockedByFailedDependency(let waiting, let dep):
            return "Service startup: '\(waiting)' skipped because dependency '\(dep)' did not start successfully."
        case .skippedAfterCriticalFailure(let waiting):
            return "Service startup: '\(waiting)' skipped — startup stopped after critical-tier failure."
        }
    }
}

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
    /// `true` if any registered service failed dependency wait or upstream dependency failed (non-fatal tiers may continue).
    @Published private(set) var startupHadFailures = false

    private var services: AppServices
    private var serviceStates: [String: ServiceState] = [:]
    private var startupQueue: [ServiceStartupItem] = []
    private var cancellables = Set<AnyCancellable>()

    init(services: AppServices) {
        self.services = services
        self.setupServicePriorities()
    }

    // MARK: - Service State Management

    private enum ServiceState: Equatable {
        case notStarted
        case starting
        case running
        case stopped
        case skippedDueToUpstreamFailure
        case failed(ServiceLifecycleCoordinatorError)

        static func == (lhs: ServiceState, rhs: ServiceState) -> Bool {
            switch (lhs, rhs) {
            case (.notStarted, .notStarted), (.starting, .starting), (.running, .running), (.stopped, .stopped),
                 (.skippedDueToUpstreamFailure, .skippedDueToUpstreamFailure):
                return true
            case let (.failed(a), .failed(b)):
                return a == b
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
            self.addService("UserService", priority: .critical, service: userService, dependencies: [])
        }
        if let configurationService = services.configurationService as? ServiceLifecycle {
            self.addService("ConfigurationService", priority: .critical, service: configurationService, dependencies: [])
        }
        if let telemetryService = services.telemetryService as? ServiceLifecycle {
            self.addService("TelemetryService", priority: .critical, service: telemetryService, dependencies: [])
        }

        // High priority services - start after critical
        if let investmentService = services.investmentService as? ServiceLifecycle {
            self.addService("InvestmentService", priority: .high, service: investmentService, dependencies: ["UserService"])
        }
        if let dashboardService = services.dashboardService as? ServiceLifecycle {
            self.addService("DashboardService", priority: .high, service: dashboardService, dependencies: ["UserService"])
        }

        // Medium priority services - start after high
        if let notificationService = services.notificationService as? ServiceLifecycle {
            self.addService("NotificationService", priority: .medium, service: notificationService, dependencies: ["UserService"])
        }
        // DocumentService always conforms to ServiceLifecycle (protocol conformance)
        let documentService = self.services.documentService as ServiceLifecycle
        self.addService("DocumentService", priority: .medium, service: documentService, dependencies: ["UserService"])

        // Low priority services - start after medium
        if let watchlistService = services.watchlistService as? ServiceLifecycle {
            self.addService("WatchlistService", priority: .low, service: watchlistService, dependencies: ["UserService"])
        }
        if let traderDataService = services.traderDataService as? ServiceLifecycle {
            self.addService("TraderDataService", priority: .low, service: traderDataService, dependencies: ["UserService"])
        }

        // Background services - start last
        if let testModeService = services.testModeService as? ServiceLifecycle {
            self.addService("TestModeService", priority: .background, service: testModeService, dependencies: [])
        }
        if let traderService = services.traderService as? ServiceLifecycle {
            self.addService("TraderService", priority: .background, service: traderService, dependencies: ["UserService"])
        }
    }

    private func addService(_ name: String, priority: ServicePriority, service: ServiceLifecycle, dependencies: [String]) {
        let item = ServiceStartupItem(
            name: name,
            priority: priority,
            service: service,
            dependencies: dependencies
        )
        self.startupQueue.append(item)
        self.serviceStates[name] = .notStarted
    }

    // MARK: - Optimized Service Startup

    func startServices() async {
        guard !self.isInitialized else { return }

        print("🚀 Starting services with optimized lifecycle...")

        self.startupHadFailures = false
        // Sort services by priority
        self.startupQueue.sort { $0.priority.rawValue < $1.priority.rawValue }

        // Start services in batches based on priority
        await self.startServicesByPriority()

        self.isInitialized = true
        print(self.startupHadFailures ? "⚠️ Service startup finished with failures (see logs)." : "✅ All services started successfully")
    }

    private func startServicesByPriority() async {
        let priorityGroups = Dictionary(grouping: startupQueue) { $0.priority }
        var abortAfterCritical = false

        priorityLoop: for priority in ServicePriority.allCases {
            guard let batch = priorityGroups[priority] else { continue }

            print("🔄 Starting \(priority) priority services...")

            for serviceItem in batch.sorted(by: { $0.name < $1.name }) {
                if abortAfterCritical {
                    if self.serviceStates[serviceItem.name] == .notStarted {
                        self.serviceStates[serviceItem.name] = .skippedDueToUpstreamFailure
                        self.startupHadFailures = true
                        let err = ServiceLifecycleCoordinatorError.skippedAfterCriticalFailure(waitingService: serviceItem.name)
                        print("⏭️ \(serviceItem.name) skipped — \(err.localizedDescription)")
                    }
                    continue
                }

                await self.startService(serviceItem)
                if priority == .critical, self.serviceStates[serviceItem.name] != .running {
                    abortAfterCritical = true
                    self.startupHadFailures = true
                    print("🛑 Aborting startup: critical service '\(serviceItem.name)' is not running.")
                }
            }

            if priority == .critical {
                let criticalNames = Set(batch.map(\.name))
                let criticalTierAllRunning = criticalNames.allSatisfy { self.serviceStates[$0] == .running }
                self.criticalServicesReady = criticalTierAllRunning && !abortAfterCritical
                if abortAfterCritical {
                    self.markRemainingServicesSkippedAfterCritical()
                    break priorityLoop
                }
            }

            if priority == .background {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }

        let allRegisteredRunning = self.startupQueue.allSatisfy {
            switch self.serviceStates[$0.name] {
            case .running: return true
            default: return false
            }
        }
        self.allServicesReady = allRegisteredRunning && !self.startupHadFailures
    }

    private func markRemainingServicesSkippedAfterCritical() {
        for item in self.startupQueue where item.priority != .critical {
            if serviceStates[item.name] == .notStarted {
                serviceStates[item.name] = .skippedDueToUpstreamFailure
            }
        }
    }

    private func dependencyWaitTimeoutNanoseconds(for item: ServiceStartupItem) -> UInt64 {
        item.priority == .critical ? 15_000_000_000 : 30_000_000_000
    }

    private func waitForDependencies(_ item: ServiceStartupItem) async -> Result<Void, ServiceLifecycleCoordinatorError> {
        let timeoutSeconds = Double(dependencyWaitTimeoutNanoseconds(for: item)) / 1_000_000_000.0
        let deadline = CFAbsoluteTimeGetCurrent() + timeoutSeconds

        while CFAbsoluteTimeGetCurrent() < deadline {
            var satisfied = true
            for dependency in item.dependencies {
                switch self.serviceStates[dependency] {
                case .running:
                    continue
                case .failed, .stopped, .skippedDueToUpstreamFailure:
                    let err = ServiceLifecycleCoordinatorError.blockedByFailedDependency(
                        waitingService: item.name,
                        dependency: dependency
                    )
                    return .failure(err)
                case .notStarted, .starting, nil:
                    satisfied = false
                }
            }
            if satisfied { return .success(()) }

            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        let firstMissing = item.dependencies.first { self.serviceStates[$0] != .running } ?? item.dependencies.first
        let dependencyName = firstMissing ?? "unknown"
        return .failure(
            ServiceLifecycleCoordinatorError.dependencyTimeout(
                waitingService: item.name,
                dependency: dependencyName,
                timeoutSeconds: timeoutSeconds
            )
        )
    }

    private func startService(_ item: ServiceStartupItem) async {
        guard self.serviceStates[item.name] == .notStarted else { return }

        switch await self.waitForDependencies(item) {
        case .failure(let err):
            self.serviceStates[item.name] = .failed(err)
            self.startupHadFailures = true
            print("⚠️ \(item.name): \(err.localizedDescription)")
            return

        case .success:
            break
        }

        self.serviceStates[item.name] = .starting

        item.service.start()
        self.serviceStates[item.name] = .running
        print("✅ \(item.name) started successfully")
    }

    // MARK: - Optimized Service Shutdown

    func stopServices() async {
        print("🛑 Stopping services...")

        // Stop services in reverse priority order
        for priority in ServicePriority.allCases.reversed() {
            let services = self.startupQueue.filter { $0.priority == priority }

            for serviceItem in services {
                if self.serviceStates[serviceItem.name] == .running {
                    serviceItem.service.stop()
                    self.serviceStates[serviceItem.name] = .stopped
                    print("🛑 \(serviceItem.name) stopped")
                }
            }
        }

        self.startupHadFailures = false
        self.isInitialized = false
        self.criticalServicesReady = false
        self.allServicesReady = false
        for item in self.startupQueue {
            self.serviceStates[item.name] = .notStarted
        }
    }

    // MARK: - Lazy Service Loading

    func startServiceOnDemand(_ serviceName: String) async {
        guard let serviceItem = startupQueue.first(where: { $0.name == serviceName }) else {
            print("⚠️ Service \(serviceName) not found")
            return
        }

        guard self.serviceStates[serviceName] == .notStarted else {
            print("ℹ️ Service \(serviceName) already started")
            return
        }

        await self.startService(serviceItem)
    }

    // MARK: - Service Health Monitoring

    func getServiceStatus() -> [String: String] {
        var status: [String: String] = [:]

        for (name, state) in self.serviceStates {
            switch state {
            case .notStarted:
                status[name] = "Not Started"
            case .starting:
                status[name] = "Starting"
            case .running:
                status[name] = "Running"
            case .stopped:
                status[name] = "Stopped"
            case .skippedDueToUpstreamFailure:
                status[name] = "Skipped"
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
