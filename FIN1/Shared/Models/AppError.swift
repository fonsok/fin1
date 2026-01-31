import Foundation

// MARK: - App Error Types
/// Centralized error handling for the FIN1 app
enum AppError: LocalizedError, Equatable {
    case validation(String)
    case network(NetworkError)
    case authentication(AuthError)
    case service(ServiceError)
    case orderNotFound(String)
    case tradeNotFound(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .validation(let message):
            return "Validation Error: \(message)"
        case .network(let error):
            return "Network Error: \(error.localizedDescription)"
        case .authentication(let error):
            return "Authentication Error: \(error.localizedDescription)"
        case .service(let error):
            return "Service Error: \(error.localizedDescription)"
        case .orderNotFound(let orderId):
            return "Order not found: \(orderId)"
        case .tradeNotFound(let tradeId):
            return "Trade not found: \(tradeId)"
        case .unknown(let message):
            return "Unknown Error: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .validation:
            return "Please check your input and try again."
        case .network:
            return "Please check your internet connection and try again."
        case .authentication:
            return "Please check your credentials and try again."
        case .service:
            return "Please try again later or contact support."
        case .orderNotFound:
            return "The order may have been cancelled or completed."
        case .tradeNotFound:
            return "The trade may have been removed or is no longer available."
        case .unknown:
            return "Please try again or contact support if the problem persists."
        }
    }
}

// MARK: - Network Error
enum NetworkError: LocalizedError, Equatable {
    case noConnection
    case timeout
    case serverError(Int)
    case invalidResponse
    case decodingError

    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .serverError(let code):
            return "Server error: \(code)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

// MARK: - Authentication Error
enum AuthError: LocalizedError, Equatable {
    case invalidCredentials
    case userNotFound
    case accountLocked
    case accountDisabled
    case emailNotVerified
    case weakPassword
    case emailAlreadyExists
    case tokenExpired
    case tokenInvalid
    case refreshFailed
    case mfaRequired
    case biometricNotAvailable
    case biometricFailed
    case userCancelled
    case providerError(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Ungültige Anmeldedaten"
        case .userNotFound:
            return "Benutzerkonto nicht gefunden"
        case .accountLocked:
            return "Konto gesperrt"
        case .accountDisabled:
            return "Konto deaktiviert"
        case .emailNotVerified:
            return "E-Mail-Adresse nicht verifiziert"
        case .weakPassword:
            return "Passwort zu schwach"
        case .emailAlreadyExists:
            return "E-Mail-Adresse bereits registriert"
        case .tokenExpired:
            return "Sitzung abgelaufen"
        case .tokenInvalid:
            return "Ungültiges Authentifizierungstoken"
        case .refreshFailed:
            return "Token-Erneuerung fehlgeschlagen"
        case .mfaRequired:
            return "Zwei-Faktor-Authentifizierung erforderlich"
        case .biometricNotAvailable:
            return "Biometrische Authentifizierung nicht verfügbar"
        case .biometricFailed:
            return "Biometrische Authentifizierung fehlgeschlagen"
        case .userCancelled:
            return "Anmeldung abgebrochen"
        case .providerError(let message):
            return "Provider-Fehler: \(message)"
        }
    }
}

// MARK: - Service Error
enum ServiceError: LocalizedError, Equatable {
    case dataNotFound
    case invalidData
    case operationFailed
    case permissionDenied
    case rateLimited
    case serviceUnavailable
    case configurationError
    case timeout

    var errorDescription: String? {
        switch self {
        case .dataNotFound:
            return "Requested data not found"
        case .invalidData:
            return "Invalid data provided"
        case .operationFailed:
            return "Operation failed"
        case .permissionDenied:
            return "Permission denied"
        case .rateLimited:
            return "Too many requests, please try again later"
        case .serviceUnavailable:
            return "Service is temporarily unavailable"
        case .configurationError:
            return "Service configuration error"
        case .timeout:
            return "Service request timed out"
        }
    }
}

// MARK: - Error Extensions
extension AppError {
    /// Create a validation error
    static func validationError(_ message: String) -> AppError {
        return .validation(message)
    }

    /// Create a network error
    static func networkError(_ error: NetworkError) -> AppError {
        return .network(error)
    }

    /// Create an authentication error
    static func authenticationError(_ error: AuthError) -> AppError {
        return .authentication(error)
    }

    /// Create a service error
    static func serviceError(_ error: ServiceError) -> AppError {
        return .service(error)
    }

    /// Create an unknown error
    static func unknownError(_ message: String) -> AppError {
        return .unknown(message)
    }
}
