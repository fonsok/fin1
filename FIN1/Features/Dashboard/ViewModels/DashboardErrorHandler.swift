import Foundation
import SwiftUI

// MARK: - Dashboard Error Handler
/// Centralized error handling for dashboard operations
final class DashboardErrorHandler: ObservableObject {
    @Published var errorMessage: String?
    @Published var showError = false

    private let telemetryService: any TelemetryServiceProtocol

    init(telemetryService: any TelemetryServiceProtocol) {
        self.telemetryService = telemetryService
    }

    // MARK: - Error Management

    func handleError(_ error: AppError, context: String, userId: String?, userRole: String?) {
        self.errorMessage = error.errorDescription ?? "An error occurred"
        self.showError = true

        // Track error with context
        let errorContext = ErrorContext(
            screen: "Dashboard",
            action: context,
            userId: userId,
            userRole: userRole,
            additionalData: [
                "error_description": error.errorDescription ?? "unknown",
                "error_recovery": error.recoverySuggestion ?? "unknown"
            ]
        )

        self.telemetryService.trackAppError(error, context: errorContext)
    }

    func clearError() {
        self.errorMessage = nil
        self.showError = false
    }

    // MARK: - Convenience Methods

    func handleDataLoadingError(_ error: Error, userId: String?, userRole: String?) {
        let appError = error.toAppError()
        self.handleError(appError, context: "data_loading", userId: userId, userRole: userRole)
    }

    func handleUserRefreshError(_ error: Error, userId: String?, userRole: String?) {
        let appError = error.toAppError()
        self.handleError(appError, context: "user_refresh", userId: userId, userRole: userRole)
    }
}
