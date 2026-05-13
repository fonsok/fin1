import Combine
@testable import FIN1
import Foundation

// MARK: - Mock Telemetry Service
class MockTelemetryService: TelemetryServiceProtocol {
    var trackedEvents: [(String, [String: Any])] = []
    var trackedErrors: [(Error, [String: Any])] = []
    var trackedAppErrors: [(AppError, ErrorContext)] = []
    var userInfo: (id: String?, role: String?) = (nil, nil)

    func trackEvent(name: String, properties: [String: Any]?) {
        self.trackedEvents.append((name, properties ?? [:]))
    }

    func trackError(_ error: Error, metadata: [String: Any]?) {
        self.trackedErrors.append((error, metadata ?? [:]))
    }

    func trackAppError(_ error: AppError, context: ErrorContext?) {
        self.trackedAppErrors.append((error, context ?? ErrorContext(screen: "Unknown")))
    }

    func setUser(id: String?, role: String?) {
        self.userInfo = (id, role)
    }

    func clearUser() {
        self.userInfo = (nil, nil)
    }

    func start() {}
    func stop() {}
    func reset() {
        self.trackedEvents.removeAll()
        self.trackedErrors.removeAll()
        self.trackedAppErrors.removeAll()
        self.userInfo = (nil, nil)
    }
}
