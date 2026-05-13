import Combine
import Foundation

// MARK: - Clean Service Protocol
/// Base protocol for all services with standardized lifecycle and event handling
protocol CleanServiceProtocol: ServiceLifecycle, EventHandler {
    var isRunning: Bool { get }
    var errorPublisher: AnyPublisher<AppError?, Never> { get }
}

// MARK: - Event Handler Protocol
/// Protocol for services that handle events from the event bus
protocol EventHandler {
    func handleEvent<T: AppEvent>(_ event: T)
}

// MARK: - Base Service Implementation
/// Base class for all services with common functionality
class BaseService: CleanServiceProtocol, ObservableObject {
    @Published var isRunning = false
    @Published var lastError: AppError?

    private var cancellables = Set<AnyCancellable>()

    var errorPublisher: AnyPublisher<AppError?, Never> {
        self.$lastError.eraseToAnyPublisher()
    }

    // MARK: - ServiceLifecycle

    func start() {
        guard !self.isRunning else { return }
        self.isRunning = true
        self.setupEventHandlers()
        self.onStart()
    }

    func stop() {
        guard self.isRunning else { return }
        self.isRunning = false
        self.cancellables.removeAll()
        self.onStop()
    }

    func reset() {
        self.stop()
        self.lastError = nil
        self.onReset()
    }

    // MARK: - EventHandler

    func handleEvent<T: AppEvent>(_ event: T) {
        // Override in subclasses to handle specific events
    }

    // MARK: - Protected Methods (Override in subclasses)

    /// Called when service starts
    func onStart() {
        // Override in subclasses
    }

    /// Called when service stops
    func onStop() {
        // Override in subclasses
    }

    /// Called when service resets
    func onReset() {
        // Override in subclasses
    }

    /// Sets up event handlers for this service
    func setupEventHandlers() {
        // Override in subclasses to subscribe to specific events
    }

    // MARK: - Helper Methods

    /// Publishes an error to the error publisher
    func publishError(_ error: AppError) {
        self.lastError = error
    }

    /// Clears the last error
    func clearError() {
        self.lastError = nil
    }

    /// Subscribes to events of a specific type
    func subscribeToEvent<T: AppEvent>(_ eventType: T.Type, handler: @escaping (T) -> Void) {
        EventBus.shared.subscribe(to: eventType)
            .sink { [weak self] event in
                guard let self = self, self.isRunning else { return }
                handler(event)
            }
            .store(in: &self.cancellables)
    }

    /// Publishes an event to the event bus
    func publishEvent<T: AppEvent>(_ event: T) {
        EventBus.shared.publish(event)
    }
}

// MARK: - Service Factory Protocol
/// Protocol for service factories to ensure consistent creation
protocol ServiceFactoryProtocol {
    func createService<T: CleanServiceProtocol>(_ serviceType: T.Type) -> T
}

// MARK: - Service Registry
/// Registry for managing service instances and their dependencies
final class ServiceRegistry: @unchecked Sendable {
    static let shared = ServiceRegistry()

    private var services: [String: Any] = [:]
    private var factories: [String: ServiceFactoryProtocol] = [:]

    private init() {}

    /// Registers a service instance
    func register<T: CleanServiceProtocol>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        self.services[key] = service
    }

    /// Registers a service factory
    func registerFactory<T: CleanServiceProtocol>(_ factory: ServiceFactoryProtocol, for type: T.Type) {
        let key = String(describing: type)
        self.factories[key] = factory
    }

    /// Resolves a service instance
    func resolve<T: CleanServiceProtocol>(_ type: T.Type) -> T? {
        let key = String(describing: type)

        // Try to get existing instance
        if let service = services[key] as? T {
            return service
        }

        // Try to create new instance using factory
        if let factory = factories[key] {
            let service = factory.createService(type)
            self.services[key] = service
            return service
        }

        return nil
    }

    /// Starts all registered services
    func startAllServices() {
        for service in self.services.values {
            if let lifecycleService = service as? ServiceLifecycle {
                lifecycleService.start()
            }
        }
    }

    /// Stops all registered services
    func stopAllServices() {
        for service in self.services.values {
            if let lifecycleService = service as? ServiceLifecycle {
                lifecycleService.stop()
            }
        }
    }

    /// Resets all registered services
    func resetAllServices() {
        for service in self.services.values {
            if let lifecycleService = service as? ServiceLifecycle {
                lifecycleService.reset()
            }
        }
    }
}
