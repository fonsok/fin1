import SwiftUI

// MARK: - App Services Environment Key
/// Environment key for injecting AppServices into the SwiftUI view hierarchy
private struct AppServicesKey: EnvironmentKey {
    static let defaultValue: AppServices = .live
}

// MARK: - Environment Values Extension
extension EnvironmentValues {
    /// Access to the app's service container
    var appServices: AppServices {
        get { self[AppServicesKey.self] }
        set { self[AppServicesKey.self] = newValue }
    }
}

// MARK: - Service Lifecycle Protocol
/// Protocol for services that need lifecycle management
protocol ServiceLifecycle {
    /// Called when the service should start (e.g., app becomes active)
    func start()

    /// Called when the service should stop (e.g., app goes to background)
    func stop()

    /// Called when the service should reset its state
    func reset()
}











