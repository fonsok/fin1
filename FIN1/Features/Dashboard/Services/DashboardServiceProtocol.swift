import Combine
import Foundation

// MARK: - Dashboard Service Protocol
/// Defines the contract for dashboard data operations and management
protocol DashboardServiceProtocol: ObservableObject, Sendable {
    var quickStats: DashboardStats { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Dashboard Data Management
    func loadDashboardData() async throws
    func refreshDashboardData() async throws
    func loadQuickStats() async throws

    func updateStats(_ stats: DashboardStats)
    func resetStats()
}
