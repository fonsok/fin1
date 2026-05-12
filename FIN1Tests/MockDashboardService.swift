import Foundation
import Combine
@testable import FIN1

// MARK: - Mock Dashboard Service
final class MockDashboardService: DashboardServiceProtocol, @unchecked Sendable {
    @Published var quickStats: DashboardStats = DashboardStats()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Test configuration
    var shouldThrowError = false
    var errorToThrow: AppError = AppError.unknownError("Test error")

    func loadDashboardData() async throws {
        if shouldThrowError {
            throw errorToThrow
        }

        await MainActor.run {
            // Mock stats loading
        }
    }

    func refreshDashboardData() async throws { try await loadDashboardData() }
    func loadQuickStats() async throws { /* noop */ }
    func updateStats(_ stats: DashboardStats) { quickStats = stats }
    func resetStats() { quickStats = DashboardStats() }

    func start() {}
    func stop() {}
    func reset() {
        isLoading = false
    }
}
