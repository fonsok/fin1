import Combine
import Foundation

// MARK: - Dashboard Service Implementation
/// Handles dashboard data operations and statistics
final class DashboardService: DashboardServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    static let shared = DashboardService()

    @Published var quickStats: DashboardStats = DashboardStats()
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        self.loadMockData()
    }

    // MARK: - ServiceLifecycle
    func start() {
        // Non-blocking start - just load mock data immediately
        self.loadMockData()
        print("🔄 DashboardService started with mock data")
    }

    func stop() {
        // Clean up any ongoing operations
    }

    func reset() {
        self.quickStats = DashboardStats()
        self.errorMessage = nil
    }

    // MARK: - Dashboard Data Management

    func loadDashboardData() async throws {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        // Simulate API call with reduced delay for better performance
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds (reduced from 0.5)

        await MainActor.run {
            self.loadQuickStatsSync()
            self.isLoading = false
        }
    }

    func refreshDashboardData() async throws {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        await MainActor.run {
            self.loadQuickStatsSync()
            self.isLoading = false
        }
    }

    func loadQuickStats() async throws {
        await MainActor.run {
            self.isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        await MainActor.run {
            self.loadQuickStatsSync()
            self.isLoading = false
        }
    }

    // MARK: - Statistics Management

    func updateStats(_ stats: DashboardStats) {
        self.quickStats = stats
    }

    func resetStats() {
        self.quickStats = DashboardStats()
    }

    // MARK: - Private Methods

    private func loadMockData() {
        self.loadQuickStatsSync()
    }

    private func loadQuickStatsSync() {
        // Mock data - in real app, this would come from API
        self.quickStats = DashboardStats(
            totalInvestmentsValue: 25_000,
            dailyChange: 1_250,
            dailyChangePercentage: 5.3,
            totalInvestments: 8,
            activeTraders: "-"
        )
    }
}
