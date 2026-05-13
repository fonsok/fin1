import Combine
@testable import FIN1
import Foundation

// MARK: - Mock Dashboard Service
final class MockDashboardService: DashboardServiceProtocol, @unchecked Sendable {
    @Published var quickStats: DashboardStats = DashboardStats()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Test configuration
    var shouldThrowError = false
    var errorToThrow: AppError = AppError.unknownError("Test error")

    func loadDashboardData() async throws {
        if self.shouldThrowError {
            throw self.errorToThrow
        }

        await MainActor.run {
            // Mock stats loading
        }
    }

    func refreshDashboardData() async throws { try await self.loadDashboardData() }
    func loadQuickStats() async throws { /* noop */ }
    func updateStats(_ stats: DashboardStats) { self.quickStats = stats }
    func resetStats() { self.quickStats = DashboardStats() }

    func start() {}
    func stop() {}
    func reset() {
        self.isLoading = false
    }
}
