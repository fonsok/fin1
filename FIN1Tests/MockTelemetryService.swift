import Foundation
import Combine
@testable import FIN1

// MARK: - Mock Telemetry Service
class MockTelemetryService: TelemetryServiceProtocol {
    var trackedEvents: [(String, [String: Any])] = []
    var trackedErrors: [(Error, [String: Any])] = []
    var trackedAppErrors: [(AppError, ErrorContext)] = []
    var userInfo: (id: String?, role: String?) = (nil, nil)

    func trackEvent(name: String, properties: [String: Any]?) {
        trackedEvents.append((name, properties ?? [:]))
    }

    func trackError(_ error: Error, metadata: [String: Any]?) {
        trackedErrors.append((error, metadata ?? [:]))
    }

    func trackAppError(_ error: AppError, context: ErrorContext?) {
        trackedAppErrors.append((error, context ?? ErrorContext(screen: "Unknown")))
    }

    func setUser(id: String?, role: String?) {
        userInfo = (id, role)
    }

    func clearUser() {
        userInfo = (nil, nil)
    }

    func start() {}
    func stop() {}
    func reset() {
        trackedEvents.removeAll()
        trackedErrors.removeAll()
        trackedAppErrors.removeAll()
        userInfo = (nil, nil)
    }
}
