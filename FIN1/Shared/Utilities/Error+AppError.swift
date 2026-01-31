import Foundation

// MARK: - Error to AppError Mapping Extension
/// Centralized error mapping utility for converting domain-specific errors to AppError
/// This ensures consistent error handling across all ViewModels following MVVM architecture
extension Error {
    /// Converts any Error to AppError for consistent error handling
    /// - Returns: AppError instance with proper categorization and localization
    func toAppError() -> AppError {
        // If already an AppError, return it
        if let appError = self as? AppError {
            return appError
        }

        // Map CustomerSupportError to AppError
        if let csError = self as? CustomerSupportError {
            switch csError {
            case .permissionDenied:
                return .service(.permissionDenied)
            case .customerNotFound:
                return .service(.dataNotFound)
            case .ticketNotFound:
                return .service(.dataNotFound)
            case .invalidRequest(let message):
                return .validation(message)
            case .complianceCheckFailed:
                return .service(.operationFailed)
            case .serviceUnavailable:
                return .service(.serviceUnavailable)
            }
        }

        // Map NetworkError to AppError
        if let networkError = self as? NetworkError {
            return .network(networkError)
        }

        // Map AuthError to AppError
        if let authError = self as? AuthError {
            return .authentication(authError)
        }

        // Map ServiceError to AppError
        if let serviceError = self as? ServiceError {
            return .service(serviceError)
        }

        // Map LocalizedError to AppError (preserves localization)
        if let localizedError = self as? LocalizedError {
            return .unknown(localizedError.errorDescription ?? localizedDescription)
        }

        // Fallback for unknown errors
        return .unknown(localizedDescription)
    }
}
