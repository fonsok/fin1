import Foundation

enum ConfigurationError: Error, LocalizedError {
    case invalidValue(String)
    case unauthorizedAccess
    case saveFailed
    case loadFailed
    case fourEyesApprovalRequired(requestId: String)
    case noBackendConnection
    case approvalRejected(reason: String)
    case serverManagedConfiguration

    var errorDescription: String? {
        switch self {
        case .invalidValue(let message): return "Invalid configuration value: \(message)"
        case .unauthorizedAccess: return "Unauthorized access to configuration settings"
        case .saveFailed: return "Failed to save configuration"
        case .loadFailed: return "Failed to load configuration"
        case .fourEyesApprovalRequired(let requestId): return "This configuration change requires 4-eyes approval. Request ID: \(requestId)"
        case .noBackendConnection: return "No backend connection available for configuration change"
        case .approvalRejected(let reason): return "Configuration change was rejected: \(reason)"
        case .serverManagedConfiguration:
            return "This setting is managed via the Admin Web Portal (Configuration, 4-eyes). The iOS app is read-only for remote configuration."
        }
    }

    var isPendingApproval: Bool {
        if case .fourEyesApprovalRequired = self { return true }
        return false
    }

    var fourEyesRequestId: String? {
        if case .fourEyesApprovalRequired(let requestId) = self { return requestId }
        return nil
    }
}
