import Combine
import Foundation

// MARK: - Dashboard Data Loader Protocol
protocol DashboardDataLoaderProtocol: Sendable {
    func loadDashboardData() async throws
    func refreshUserData() async throws
}

// MARK: - Dashboard Data Loader Implementation
final class DashboardDataLoader: DashboardDataLoaderProtocol, @unchecked Sendable {
    private let userService: any UserServiceProtocol
    private let dashboardService: any DashboardServiceProtocol
    private let telemetryService: any TelemetryServiceProtocol

    init(
        userService: any UserServiceProtocol,
        dashboardService: any DashboardServiceProtocol,
        telemetryService: any TelemetryServiceProtocol
    ) {
        self.userService = userService
        self.dashboardService = dashboardService
        self.telemetryService = telemetryService
    }

    // MARK: - Data Loading

    func loadDashboardData() async throws {
        do {
            try await self.dashboardService.loadDashboardData()
        } catch let error as AppError {
            await trackError(error, context: "dashboard_data_loading")
            throw error
        } catch {
            let appError = error.toAppError()
            await self.trackError(appError, context: "dashboard_data_loading")
            throw appError
        }
    }

    func refreshUserData() async throws {
        do {
            try await self.userService.refreshUserData()
        } catch let error as AppError {
            await trackError(error, context: "user_data_refresh")
            throw error
        } catch {
            let appError = error.toAppError()
            await self.trackError(appError, context: "user_data_refresh")
            throw appError
        }
    }

    // MARK: - Error Tracking

    private func trackError(_ error: AppError, context: String) async {
        let errorContext = ErrorContext(
            screen: "Dashboard",
            action: context,
            userId: userService.currentUser?.id,
            userRole: self.userService.currentUser?.role.displayName,
            additionalData: [
                "user_display_name": self.userService.userDisplayName,
                "is_investor": self.userService.isInvestor,
                "is_trader": self.userService.isTrader
            ]
        )

        await MainActor.run {
            self.telemetryService.trackAppError(error, context: errorContext)
        }
    }
}
