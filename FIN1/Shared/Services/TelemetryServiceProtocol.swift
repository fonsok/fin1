import Foundation
import Combine

// MARK: - Telemetry Service Protocol
protocol TelemetryServiceProtocol: AnyObject {
    func trackEvent(name: String, properties: [String: Any]?)
    func trackError(_ error: Error, metadata: [String: Any]?)
    func trackAppError(_ error: AppError, context: ErrorContext?)
    func setUser(id: String?, role: String?)
    func clearUser()
}

// MARK: - Error Context
struct ErrorContext {
    let screen: String
    let action: String?
    let userId: String?
    let userRole: String?
    let timestamp: Date
    let additionalData: [String: Any]?

    init(screen: String, action: String? = nil, userId: String? = nil, userRole: String? = nil, additionalData: [String: Any]? = nil) {
        self.screen = screen
        self.action = action
        self.userId = userId
        self.userRole = userRole
        self.timestamp = Date()
        self.additionalData = additionalData
    }
}

// MARK: - Telemetry Service Implementation (No-op / Console Logger)
final class TelemetryService: TelemetryServiceProtocol, ServiceLifecycle {
    static let shared = TelemetryService()
    private let queue = DispatchQueue(label: "telemetry.queue")

    init() {}

    // MARK: - ServiceLifecycle
    func start() { /* e.g., establish session, flush pending queue */ }
    func stop() { /* e.g., flush and suspend */ }
    func reset() { clearUser() }

    // MARK: - Telemetry
    func trackEvent(name: String, properties: [String: Any]?) {
        #if DEBUG
        print("📊 Telemetry Event: \(name) props=\(properties ?? [:])")
        #endif
    }

    func trackError(_ error: Error, metadata: [String: Any]?) {
        #if DEBUG
        print("⚠️ Telemetry Error: \(error.localizedDescription) meta=\(metadata ?? [:])")
        #endif
    }

    func trackAppError(_ error: AppError, context: ErrorContext?) {
        let errorMetadata: [String: Any] = [
            "error_type": errorType(for: error),
            "error_category": errorCategory(for: error),
            "error_message": error.localizedDescription,
            "recovery_suggestion": error.recoverySuggestion ?? "No suggestion available",
            "screen": context?.screen ?? "Unknown",
            "action": context?.action ?? "Unknown",
            "user_id": context?.userId ?? "Unknown",
            "user_role": context?.userRole ?? "Unknown",
            "timestamp": context?.timestamp ?? Date(),
            "additional_data": context?.additionalData ?? [:]
        ]

        #if DEBUG
        print("🚨 App Error Tracked:")
        print("   Type: \(errorMetadata["error_type"] ?? "Unknown")")
        print("   Category: \(errorMetadata["error_category"] ?? "Unknown")")
        print("   Screen: \(errorMetadata["screen"] ?? "Unknown")")
        print("   Action: \(errorMetadata["action"] ?? "Unknown")")
        print("   Message: \(errorMetadata["error_message"] ?? "Unknown")")
        print("   User: \(errorMetadata["user_id"] ?? "Unknown") (\(errorMetadata["user_role"] ?? "Unknown"))")
        #endif

        // In production, this would send to your analytics service
        // Example: Analytics.track("app_error", properties: errorMetadata)
    }

    private func errorType(for error: AppError) -> String {
        switch error {
        case .validation: return "validation"
        case .network: return "network"
        case .authentication: return "authentication"
        case .service: return "service"
        case .orderNotFound: return "order_not_found"
        case .tradeNotFound: return "trade_not_found"
        case .unknown: return "unknown"
        }
    }

    private func errorCategory(for error: AppError) -> String {
        switch error {
        case .validation(let message):
            return message.contains("email") ? "email_validation" : "input_validation"
        case .network(let networkError):
            switch networkError {
            case .noConnection: return "no_connection"
            case .timeout: return "timeout"
            case .serverError: return "server_error"
            case .invalidResponse: return "invalid_response"
            case .decodingError: return "decoding_error"
            }
        case .authentication(let authError):
            switch authError {
            case .invalidCredentials: return "invalid_credentials"
            case .userNotFound: return "user_not_found"
            case .accountLocked: return "account_locked"
            case .accountDisabled: return "account_disabled"
            case .emailNotVerified: return "email_not_verified"
            case .weakPassword: return "weak_password"
            case .emailAlreadyExists: return "email_already_exists"
            case .tokenExpired: return "token_expired"
            case .tokenInvalid: return "token_invalid"
            case .refreshFailed: return "refresh_failed"
            case .mfaRequired: return "mfa_required"
            case .biometricNotAvailable: return "biometric_not_available"
            case .biometricFailed: return "biometric_failed"
            case .userCancelled: return "user_cancelled"
            case .providerError: return "provider_error"
            }
        case .service(let serviceError):
            switch serviceError {
            case .dataNotFound: return "data_not_found"
            case .invalidData: return "invalid_data"
            case .operationFailed: return "operation_failed"
            case .permissionDenied: return "permission_denied"
            case .rateLimited: return "rate_limited"
            case .serviceUnavailable: return "service_unavailable"
            case .configurationError: return "configuration_error"
            case .timeout: return "timeout"
            }
        case .orderNotFound: return "order_not_found"
        case .tradeNotFound: return "trade_not_found"
        case .unknown: return "unknown_error"
        }
    }

    func setUser(id: String?, role: String?) {
        #if DEBUG
        print("👤 Telemetry User: id=\(id ?? "nil") role=\(role ?? "nil")")
        #endif
    }

    func clearUser() {
        #if DEBUG
        print("👤 Telemetry User: cleared")
        #endif
    }
}
